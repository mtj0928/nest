import ArgumentParser
import Foundation
import NestKit
import Logging

@main
struct Nest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nest",
        subcommands: [
            InstallCommand.self,
            UninstallCommand.self,
            ListCommand.self,
            SwitchCommand.self,
            BootstrapCommand.self,
            GenerateNestfileCommand.self
        ]
    )
}

extension Configuration {
    static func make(
        nestPath: String?,
        logLevel: Logger.Level,
        httpClient: some HTTPClient = URLSession.shared,
        fileSystem: some FileSystem = FileManager.default
    ) -> Configuration {
        let nestDirectory = NestDirectory(
            rootDirectory: nestPath.map { URL(filePath: $0) } ?? fileSystem.defaultNestPath
        )

        var logger = Logger(label: "com.github.mtj0928.nest")
        logger.logLevel = logLevel
        logger.debug("NEST_PATH: \(nestDirectory.rootDirectory.path()).")

        return Configuration(
            httpClient: httpClient,
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(
                httpClient: httpClient,
                fileSystem: fileSystem,
                checksumCalculator: SwiftChecksumCalculator(swift: SwiftCommand(
                    executor: NestProcessExecutor(logger: logger)
                )),
                logger: logger
            ),
            workingDirectory: fileSystem.temporaryDirectory.appending(path: "nest"),
            nestDirectory: nestDirectory,
            artifactBundleManager: ArtifactBundleManager(fileSystem: fileSystem, directory: nestDirectory),
            logger: logger
        )
    }
}

extension FileSystem {
    var defaultNestPath: URL {
        homeDirectoryForCurrentUser.appending(component: ".nest")
    }
}

extension ProcessInfo {
    var nestPath: String? {
        environment["NEST_PATH"]
    }
}
