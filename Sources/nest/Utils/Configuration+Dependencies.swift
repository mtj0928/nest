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
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: httpClient, fileSystem: fileSystem),
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }

    var swiftPackageBuilder: SwiftPackageBuilder {
        SwiftPackageBuilder(
            workingDirectory: workingDirectory,
            fileSystem: fileSystem,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }
}
