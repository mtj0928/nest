import ArgumentParser
import Foundation
import NestKit
import Logging

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install a repository"
    )

    @Argument(help: "A repository you want to install. (e.g., `owner/repository` or \"https://github.com/...\")")
    var repositoryURL: GitURL

    @Argument
    var version: GitVersion = .latestRelease

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        LoggingSystem.bootstrap()
        if verbose {
            logger.logLevel = .trace
        }

        let executableBinaries = try await fetchOrBuildExecutableBinary()
        for binary in executableBinaries {
            try nestFileManager.install(binary)
            logger.info("🪺 Success to install \(binary.commandName).", metadata: .color(.green))
        }
    }

    private func fetchOrBuildExecutableBinary() async throws -> [ExecutableBinary] {
        switch repositoryURL {
        case .url(let url):
            do {
                return try await fetchArtifactBundle(for: url)
            } catch InstallError.noCandidates {
                logger.info("🪹 No artifact bundles in the repository.")
                return try await buildBinary(gitURL: repositoryURL)
            } catch GitRepositoryClientError.notFound {
                logger.info("🪹 No releases in the repository.")
                return try await buildBinary(gitURL: repositoryURL)
            } catch {
                logger.error(error)
                return try await buildBinary(gitURL: repositoryURL)
            }
        case .ssh(_):
            logger.info("Specify a https url if you want to download an artifact bundle.")
            return try await buildBinary(gitURL: repositoryURL)
        }
    }

    private func fetchArtifactBundle(for url: URL) async throws -> [ExecutableBinary] {
        let repositoryClient = GitRepositoryClientBuilder.build(url: repositoryURL, configuration: configuration)

        // Fetch asset information from the remove repository
        let assetInfo = try await repositoryClient.fetchAssets(repositoryURL: url, version: version)
        let assets = assetInfo.assets

        // Choose an asset which may be an artifact bundle.
        guard let selectedAsset = ArtifactBundleAssetSelector().selectArtifactBundle(from: assets) else {
            throw InstallError.noCandidates
        }
        logger.info("📦 Found an artifact bundle, \(selectedAsset.fileName), for \(url.lastPathComponent).")

        // Reset the existing directory.
        let repositoryDirectory = workingDirectory.appending(component: url.lastPathComponent)
        try fileManager.removeItemIfExists(at: repositoryDirectory)

        // Download the artifact bundle
        logger.info("🌐 Downloading the artifact bundle of \(url.lastPathComponent)...")
        try await zipFileDownloader.download(url: selectedAsset.url, to: repositoryDirectory)
        logger.info("✅ Success to download the artifact bundle of \(url.lastPathComponent).", metadata: .color(.green))

        // Get the current triple.
        let triple = try await TripleDetector(logger: logger).detect()
        logger.debug("The current triple is \(triple)")

        return try fileManager.child(extension: "artifactbundle", at: repositoryDirectory)
            .compactMap { artifactBundlePath in try ArtifactBundleRootDirectory(at: artifactBundlePath) }
            .flatMap { bundle in bundle.binaries(of: triple) }
            .map { binaryInfo in ExecutableBinary(gitURL: repositoryURL, binaryInfo: binaryInfo) }
    }

    private func buildBinary(gitURL: GitURL) async throws -> [ExecutableBinary] {
        let repositoryDirectory = workingDirectory.appending(component: gitURL.repositoryName)
        try fileManager.removeItemIfExists(at: repositoryDirectory)

        let tagOrVersion = try await resolveTagOrVersion()
        logger.info("🔄 Cloning \(gitURL.repositoryName)...")

        try await GitCommand(logger: logger).clone(repositoryURL: gitURL, tag: tagOrVersion, to: repositoryDirectory)
        let branch = try await GitCommand(currentDirectoryURL: repositoryDirectory, logger: logger).currentBranch()

        logger.info("🔨 Building \(gitURL.repositoryName) for \(tagOrVersion ?? branch)...")

        let swiftCommand = SwiftCommand(currentDirectoryURL: repositoryDirectory, logger: logger)
        try await swiftCommand.buildForRelease()

        return try await swiftCommand.description()
            .executableNames
            .map { executableName in
                let binaryPath = repositoryDirectory.appending(components: ".build", "release", executableName)
                return ExecutableBinary(
                    commandName: executableName,
                    binaryPath: binaryPath,
                    gitURL: gitURL,
                    version: tagOrVersion ?? branch,
                    manufacturer: .localBuild
                )
            }
    }

    private func resolveTagOrVersion() async throws -> String? {
        switch (version, repositoryURL) {
        case (.latestRelease, .url(let url)):
            let repositoryClient = GitRepositoryClientBuilder.build(url: repositoryURL, configuration: configuration)
            return try? await repositoryClient.fetchAssets(repositoryURL: url, version: .latestRelease).tagName

        case (.latestRelease, .ssh):
            return nil

        case (.tag(let tagName), _):
            return tagName
        }
    }
}

extension ExecutableBinary {
    init(gitURL: GitURL, binaryInfo: BinaryInfo) {
        self.init(
            commandName: binaryInfo.commandName,
            binaryPath: binaryInfo.binaryPath,
            gitURL: gitURL,
            version: binaryInfo.version,
            manufacturer: .artifactBundle(fileName: binaryInfo.artifactBundleName)
        )
    }
}

struct BinaryInfo {
    var commandName: String
    var binaryPath: URL
    var version: String
    var artifactBundleName: String
}

extension GitVersion: ExpressibleByArgument {
    public init?(argument: String) {
        self = .tag(argument)
    }

    public var defaultValueDescription: String {
        description
    }
}

extension ArtifactBundleRootDirectory {
    func binaries(of triple: String) -> [BinaryInfo] {
        info.artifacts.flatMap { name, artifact in
            artifact.variants
                .filter { variant in variant.supportedTriples.contains(triple) }
                .map { variant in variant.path }
                .map { variantPath in rootDirectory.appending(path: variantPath) }
                .map { binaryPath in
                    let fileName = rootDirectory.fileNameWithoutPathExtension
                    return BinaryInfo(
                        commandName: name,
                        binaryPath: binaryPath, 
                        version: artifact.version,
                        artifactBundleName: fileName
                    )
                }
        }
    }
}

enum InstallError: LocalizedError {
    case noCandidates

    var errorDescription: String? {
        switch self {
        case .noCandidates: "No candidates for artifact bundle in the repository, please specify the file name."
        }
    }
}

extension GitURL: ExpressibleByArgument {
    public init?(argument: String) {
        guard let url = GitURL.parse(string: argument) else { return nil }
        self = url
    }
}

extension AsyncParsableCommand {
    var configuration: Configuration {
        get { Configuration.default }
        set { Configuration.default = newValue }
    }
    var urlSession: URLSession { configuration.urlSession }
    var fileManager: FileManager { configuration.fileManager }
    var logger: Logger {
        get { configuration.logger }
        set { configuration.logger = newValue }
    }
    var zipFileDownloader: ZipFileDownloader { ZipFileDownloader(urlSession: urlSession, fileManager: fileManager) }
    var workingDirectory: URL { fileManager.temporaryDirectory.appending(path: "nest") }
    var nestDirectory: NestDirectory {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let dotNestDirectory = homeDirectory.appending(path: ".nest")
        return NestDirectory(rootDirectory: dotNestDirectory)
    }
    var nestFileManager: NestFileManager {
        NestFileManager(fileManager: fileManager, directory: nestDirectory)
    }
}
