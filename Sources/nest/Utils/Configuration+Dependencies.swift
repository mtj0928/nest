import ArgumentParser
import Foundation
import Logging
import NestCLI
import NestKit

extension Configuration {

    var zipFileDownloader: ZipFileDownloader {
        ZipFileDownloader(urlSession: urlSession, fileManager: fileManager)
    }

    var workingDirectory: URL {
        fileManager.temporaryDirectory.appending(path: "nest")
    }

    var nestDirectory: NestDirectory {
        if let configuredStringPath = ProcessInfo.processInfo.environment["NEST_PATH"] {
            logger.debug("$NEST_PATH: \(configuredStringPath).")
            let configuredPath = URL(fileURLWithPath: configuredStringPath)
            return NestDirectory(rootDirectory: configuredPath)
        } else {
            logger.debug("$NEST_PATH is not set.")
            let homeDirectory = fileManager.homeDirectoryForCurrentUser
            let dotNestDirectory = homeDirectory.appending(path: ".nest")
            return NestDirectory(rootDirectory: dotNestDirectory)
        }
    }

    var nestFileManager: NestFileManager {
        NestFileManager(fileManager: fileManager, directory: nestDirectory)
    }
}

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
            zipFileDownloader: ZipFileDownloader(urlSession: urlSession, fileManager: fileManager),
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }

    var swiftPackageBuilder: SwiftPackageBuilder {
        SwiftPackageBuilder(
            workingDirectory: workingDirectory,
            fileManager: fileManager,
            repositoryClientBuilder: GitRepositoryClientBuilder(configuration: self),
            logger: logger
        )
    }
}
