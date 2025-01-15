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

    private var artifactBundleFetcher: ArtifactBundleFetcher {
        ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: NestProcessExecutorBuilder(logger: logger),
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: httpClient),
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: assetRegistryClientBuilder,
            logger: logger
        )
    }

    private var swiftPackageBuilder: SwiftPackageBuilder {
        SwiftPackageBuilder(
            workingDirectory: workingDirectory,
            executorBuilder: NestProcessExecutorBuilder(logger: logger),
            fileSystem: fileSystem,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: assetRegistryClientBuilder,
            logger: logger
        )
    }
}
