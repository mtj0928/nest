import Foundation
import NestKit
import Logging

public struct ExecutableBinaryPreparer {
    private let artifactBundleFetcher: ArtifactBundleFetcher
    private let swiftPackageBuilder: SwiftPackageBuilder
    private let logger: Logger

    public init(
        artifactBundleFetcher: ArtifactBundleFetcher,
        swiftPackageBuilder: SwiftPackageBuilder,
        logger: Logger
    ) {
        self.artifactBundleFetcher = artifactBundleFetcher
        self.swiftPackageBuilder = swiftPackageBuilder
        self.logger = logger
    }

    public func fetchOrBuildBinariesFromGitRepository(
        at gitURL: GitURL,
        version: GitVersion
    ) async throws -> [ExecutableBinary] {
        switch gitURL {
        case .url(let url):
            do {
                return try await artifactBundleFetcher.fetchArtifactBundleFromGitRepository(for: url, version: version)
            } catch ArtifactBundleFetcherError.noCandidates {
                logger.info("🪹 No artifact bundles in the repository.")
            } catch ArtifactBundleFetcherError.unsupportedTriple {
                logger.info("🪹 No binaries corresponding to the current triple.")
            } catch GitRepositoryClientError.notFound {
                logger.info("🪹 No releases in the repository.")
            } catch NestCLIError.alreadyInstalled {
                logger.info("🪺 The artifact bundle has been already installed.")
                return []
            }
            catch {
                logger.error(error)
            }
        case .ssh:
            logger.info("Specify a https url if you want to download an artifact bundle.")
        }

        do {
            return try await swiftPackageBuilder.build(gitURL: gitURL, version: version)
        }
        catch NestCLIError.alreadyInstalled {
            logger.info("🪺 The artifact bundle has been already installed.")
            return []
        }
    }   

    public func fetchArtifactBundle(at url: URL) async throws -> [ExecutableBinary] {
        do {
            return try await artifactBundleFetcher.downloadArtifactBundle(url: url)
        }
        catch NestCLIError.alreadyInstalled {
            logger.info("🪺 The artifact bundle has been already installed.")
            return []
        }
    }
}
