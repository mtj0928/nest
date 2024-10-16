import ArgumentParser
import Foundation
import Logging
import NestCLI
import NestKit

extension Configuration {

    var executableBinaryPreparer: ExecutableBinaryPreparer {
        ExecutableBinaryPreparer(
            artifactBundleFetcher: artifactBundleFetcher,
            swiftPackageBuilder: swiftPackageBuilder,
            logger: logger
        )
    }

    var artifactBundleFetcher: ArtifactBundleFetcher {
        ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            fileManager: fileManager,
            fileDownloader: NestFileDownloader(urlSession: urlSession, fileManager: fileManager),
            nestInfoController: NestInfoController(directory: nestDirectory, fileManager: fileManager),
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }

    var swiftPackageBuilder: SwiftPackageBuilder {
        SwiftPackageBuilder(
            workingDirectory: workingDirectory,
            fileManager: fileManager,
            nestInfoController: NestInfoController(directory: nestDirectory, fileManager: fileManager),
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }
}
