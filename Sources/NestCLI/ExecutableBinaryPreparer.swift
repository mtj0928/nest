import Foundation
import NestKit
import Logging

public struct ExecutableBinaryPreparer {
    private let artifactBundleFetcher: ArtifactBundleFetcher
    private let swiftPackageBuilder: SwiftPackageBuilder
    private let nestInfoController: NestInfoController
    private let artifactBundleManager: ArtifactBundleManager
    private let logger: Logger

    public init(
        artifactBundleFetcher: ArtifactBundleFetcher,
        swiftPackageBuilder: SwiftPackageBuilder,
        nestInfoController: NestInfoController,
        artifactBundleManager: ArtifactBundleManager,
        logger: Logger
    ) {
        self.artifactBundleFetcher = artifactBundleFetcher
        self.swiftPackageBuilder = swiftPackageBuilder
        self.nestInfoController = nestInfoController
        self.artifactBundleManager = artifactBundleManager
        self.logger = logger
    }

    public func resolveInstalledExecutableBinariesFromNestInfo(for gitURL: GitURL, version: GitVersion) -> [ExecutableBinary]? {
        let commands = nestInfoController.getInfo().commands
            .compactMapValues { commands -> [NestInfo.Command]? in
                let filteredCommands = commands.filter { command in
                    command.repository?.reference == gitURL && command.version == version.description
                }
                if filteredCommands.isEmpty {
                    return nil
                }
                return filteredCommands
            }
        if commands.isEmpty {
            return nil
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
            try artifactBundleManager.install(binary)
            logger.info("🪺 Success to install \(binary.commandName) version \(binary.version).")
        }
    }

    public func fetchOrBuildBinariesFromGitRepository(
        at gitURL: GitURL,
        version: GitVersion,
        artifactBundleZipFileName: String?,
        checksum: ChecksumOption
    ) async throws -> [ExecutableBinary] {
        switch gitURL {
        case .url(let url):
            do {
                return try await artifactBundleFetcher.fetchArtifactBundleFromGitRepository(
                    for: url,
                    version: version,
                    artifactBundleZipFileName: artifactBundleZipFileName,
                    checksum: checksum
                )
            } catch ArtifactBundleFetcherError.noCandidates {
                logger.info("🪹 No artifact bundles in the repository.")
            } catch ArtifactBundleFetcherError.unsupportedTriple {
                logger.info("🪹 No binaries corresponding to the current triple.")
            } catch AssetRegistryClientError.notFound {
                logger.info("🪹 No releases in the repository.")
            } catch NestCLIError.alreadyInstalled {
                logger.info("🪺 The artifact bundle has been already installed.")
                return []
            } catch {
                logger.error(error)
            }
        case .ssh:
            logger.info("Specify a https url if you want to download an artifact bundle.")
        }

        do {
            return try await swiftPackageBuilder.build(gitURL: gitURL, version: version)
        } catch NestCLIError.alreadyInstalled {
            logger.info("🪺 The artifact bundle has been already installed.")
            return []
        }
    }   

    public func fetchArtifactBundle(at url: URL, checksum: ChecksumOption) async throws -> [ExecutableBinary] {
        do {
            return try await artifactBundleFetcher.downloadArtifactBundle(url: url, checksum: checksum)
        } catch NestCLIError.alreadyInstalled {
            logger.info("🪺 The artifact bundle has been already installed.")
            return []
        }
    }
}
