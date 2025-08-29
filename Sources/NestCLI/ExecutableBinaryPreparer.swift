import Foundation
import NestKit
import Logging

public struct ExecutableBinaryPreparer {
    private let directory: NestDirectory
    private let artifactBundleFetcher: ArtifactBundleFetcher
    private let swiftPackageBuilder: SwiftPackageBuilder
    private let nestInfoController: NestInfoController
    private let artifactBundleManager: ArtifactBundleManager
    private let logger: Logger

    public init(
        directory: NestDirectory,
        artifactBundleFetcher: ArtifactBundleFetcher,
        swiftPackageBuilder: SwiftPackageBuilder,
        nestInfoController: NestInfoController,
        artifactBundleManager: ArtifactBundleManager,
        logger: Logger
    ) {
        self.directory = directory
        self.artifactBundleFetcher = artifactBundleFetcher
        self.swiftPackageBuilder = swiftPackageBuilder
        self.nestInfoController = nestInfoController
        self.artifactBundleManager = artifactBundleManager
        self.logger = logger
    }
    /// Installs binaries in the given repository.
    /// - Parameters:
    ///   - gitURL: A git repository which should be installed.
    ///   - version: A version of the repository
    ///   - assetName: An asset name of an artifact bundle if it is known. `nil` can be accepted but additional API requests are required in that case.
    ///   - checksumOption: A checksum option.
    public func installBinaries(
        gitURL: GitURL,
        version: GitVersion,
        assetName: String?,
        checksumOption: ChecksumOption
    ) async throws {
        let executableBinaries = try await fetchOrBuildBinariesFromGitRepository(
            at: gitURL,
            version: version,
            artifactBundleZipFileName: assetName,
            checksum: checksumOption
        )

        for binary in executableBinaries {
            let executableBinary = binary.executableBinary
            if binary.isAlreadyInstalled {
                logger.info("🪺 Skip to install \(executableBinary.commandName) version \(executableBinary.version) because it's already installed.")
            } else {
                try artifactBundleManager.install(executableBinary)
                logger.info("🪺 Success to install \(executableBinary.commandName) version \(executableBinary.version).")
            }
        }
    }

    public func fetchOrBuildBinariesFromGitRepository(
        at gitURL: GitURL,
        version: GitVersion,
        artifactBundleZipFileName: String?,
        checksum: ChecksumOption
    ) async throws -> [PreparedBinary] {
        switch gitURL {
        case .url(let url):
            do {
                return try await artifactBundleFetcher.fetchArtifactBundleFromGitRepository(
                    for: url,
                    version: version,
                    artifactBundleZipFileName: artifactBundleZipFileName,
                    checksum: checksum
                )
                .map { PreparedBinary(executableBinary: $0, isAlreadyInstalled: false) }
            } catch ArtifactBundleFetcherError.noCandidates {
                logger.info("🪹 No artifact bundles in the repository.")
            } catch ArtifactBundleFetcherError.unsupportedTriple {
                logger.info("🪹 No binaries corresponding to the current triple.")
            } catch AssetRegistryClientError.notFound {
                logger.info("🪹 No releases in the repository.")
            } catch NestCLIError.alreadyInstalled {
                logger.info("🪺 The artifact bundle has been already installed.")
                return resolveInstalledExecutableBinariesFromNestInfo(for: gitURL, version: version)
                    .map { PreparedBinary(executableBinary: $0, isAlreadyInstalled: true) }
            } catch {
                logger.error(error)
            }
        case .ssh:
            logger.info("Specify a https url if you want to download an artifact bundle.")
        }

        do {
            return try await swiftPackageBuilder.build(gitURL: gitURL, version: version)
                .map { PreparedBinary(executableBinary: $0, isAlreadyInstalled: false) }
        } catch NestCLIError.alreadyInstalled {
            logger.info("🪺 The artifact bundle has been already installed.")
            return resolveInstalledExecutableBinariesFromNestInfo(for: gitURL, version: version)
                .map { PreparedBinary(executableBinary: $0, isAlreadyInstalled: true) }
        }
    }   

    public func fetchArtifactBundle(at url: URL, checksum: ChecksumOption) async throws -> [PreparedBinary] {
        do {
            return try await artifactBundleFetcher.downloadArtifactBundle(url: url, checksum: checksum)
                .map { PreparedBinary(executableBinary: $0, isAlreadyInstalled: false) }
        } catch NestCLIError.alreadyInstalled {
            logger.info("🪺 The artifact bundle has been already installed.")
            return resolveInstalledExecutableBinariesFromNestInfo(for: url)
                .map { PreparedBinary(executableBinary: $0, isAlreadyInstalled: true) }
        }
    }

    public func resolveInstalledExecutableBinariesFromNestInfo(for gitURL: GitURL, version: GitVersion) -> [ExecutableBinary] {
        let commands = nestInfoController.getInfo().commands
            .compactMapValues { commands -> [NestInfo.Command]? in
                let filteredCommands = commands.filter { command in
                    command.repository?.reference == gitURL && command.version == version.description
                }
                return filteredCommands.isEmpty ? nil : filteredCommands
            }
        return commands
            .flatMap { commandName, commands in commands.map { (commandName, $0) }}
            .map { commandName, command in
                ExecutableBinary(
                    commandName: commandName,
                    binaryPath: directory.rootDirectory.appending(component: command.binaryPath),
                    version: command.version,
                    manufacturer: command.manufacturer
                )
            }
    }

    public func resolveInstalledExecutableBinariesFromNestInfo(for url: URL) -> [ExecutableBinary] {
        let commands = nestInfoController.getInfo().commands
            .compactMapValues { commands -> [NestInfo.Command]? in
                let filteredCommands = commands.filter { command in
                    command.manufacturer == .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: url, repository: nil))
                }
                return filteredCommands.isEmpty ? nil : filteredCommands
            }
        return commands
            .flatMap { commandName, commands in commands.map { (commandName, $0) }}
            .map { commandName, command in
                ExecutableBinary(
                    commandName: commandName,
                    binaryPath: URL(filePath: command.binaryPath),
                    version: command.version,
                    manufacturer: command.manufacturer
                )
            }
    }

}

public struct PreparedBinary: Sendable {
    public var executableBinary: ExecutableBinary

    /// A boolean indicating the binary is already installed to `.nest/artifacts/`.
    /// Note that the binary might not be selected even if the value is `true`.
    public var isAlreadyInstalled: Bool
}
