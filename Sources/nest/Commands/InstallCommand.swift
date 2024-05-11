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
    var tag: String = "latest"

    func run() async throws {
        LoggingSystem.bootstrap()

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
                logger.info("⚙️ Start to build the repository.")
                // TODO: Need to clone and build the repository.
                return []
            } catch {
                logger.error(error)
                // TODO: Need to clone and build the repository as a fallback
                return []
            }
        case .ssh(_):
            logger.info("Specify a https url if you want to download an artifact bundle.")
            return []
        }
    }

    private func fetchArtifactBundle(for url: URL) async throws -> [ExecutableBinary] {
        let repositoryClient = GitRepositoryClientBuilder.build(url: repositoryURL, configuration: configuration)

        // Fetch asset information from the remove repository
        let assetInfo = try await repositoryClient.fetchAssets(repositoryURL: url, tag: tag)
        let assets = assetInfo.assets
        let tagName = assetInfo.tagName

        // Choose an asset which may be an artifact bundle.
        guard let selectedAsset = ArtifactBundleAssetSelector().selectArtifactBundle(from: assets) else {
            throw InstallError.noCandidates
        }
        logger.info("📦 Found an artifact bundle, \(selectedAsset.fileName), for \(url.lastPathComponent).")

        // Reset the existing directory.
        let repositoryDirectory = workingDirectory.appending(component: url.lastPathComponent)
        try fileManager.removeItemIfExists(at: repositoryDirectory)

        // Download the artifact bundle
        logger.info("🌐 Downloading the artifact bundle of \(url.lastPathComponent).")
        try await zipFileDownloader.download(url: selectedAsset.url, to: repositoryDirectory)
        logger.info("✅ Success to download the artifact bundle of \(url.lastPathComponent).", metadata: .color(.green))

        // Get the current triple.
        let triple = try await TripleDetector().detect()
        logger.debug("The current triple is \(triple)")

        return try fileManager.child(extension: "artifactbundle", at: repositoryDirectory)
            .compactMap { artifactBundlePath in try ArtifactBundleRootDirectory(at: artifactBundlePath) }
            .flatMap { bundle in bundle.binaries(of: triple) }
            .map { binaryInfo in ExecutableBinary(gitURL: repositoryURL, version: tagName, binaryInfo: binaryInfo) }
    }
}

extension ExecutableBinary {
    init(gitURL: GitURL, version: String, binaryInfo: BinaryInfo) {
        self.init(
            commandName: binaryInfo.commandName,
            binaryPath: binaryInfo.binaryPath,
            gitURL: gitURL,
            version: version,
            artifactBundleFileName: binaryInfo.artifactBundleName
        )
    }
}

struct BinaryInfo {
    var commandName: String
    var binaryPath: URL
    var artifactBundleName: String
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
                    return BinaryInfo(commandName: name, binaryPath: binaryPath, artifactBundleName: fileName)
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
    var configuration: Configuration { Configuration.default }
    var urlSession: URLSession { configuration.urlSession }
    var fileManager: FileManager { configuration.fileManager }
    var logger: Logger { configuration.logger }
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
