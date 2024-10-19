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
            executorBuilder: NestProcessExecutorBuilder(logger: logger),
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(
                httpClient: httpClient,
                fileSystem: fileSystem,
                checksumCalculator: SwiftChecksumCalculator(swift: SwiftCommand(executor: NestProcessExecutor(logger: logger))),
                logger: logger
            ),
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            repositoryClientBuilder: GitRepositoryClientBuilder(httpClient: httpClient, logger: logger),
            logger: logger
        )
    }

    var swiftPackageBuilder: SwiftPackageBuilder {
        SwiftPackageBuilder(
            workingDirectory: workingDirectory,
            executorBuilder: NestProcessExecutorBuilder(logger: logger),
            fileSystem: fileSystem,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            repositoryClientBuilder: GitRepositoryClientBuilder(httpClient: httpClient, logger: logger),
            logger: logger
        )
    }
}
