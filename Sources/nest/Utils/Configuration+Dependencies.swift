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
            fileStorage: fileStorage,
            fileDownloader: NestFileDownloader(httpClient: httpClient, fileStorage: fileStorage),
            nestInfoController: NestInfoController(directory: nestDirectory, fileStorage: fileStorage),
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }

    var swiftPackageBuilder: SwiftPackageBuilder {
        SwiftPackageBuilder(
            workingDirectory: workingDirectory,
            fileStorage: fileStorage,
            nestInfoController: NestInfoController(directory: nestDirectory, fileStorage: fileStorage),
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }
}
