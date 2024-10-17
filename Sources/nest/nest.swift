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
        urlSession: URLSession = .shared,
        fileStorage: some FileStorage = FileManager.default
    ) -> Configuration {
        let nestDirectory = NestDirectory(
            rootDirectory: nestPath.map { URL(filePath: $0) } ?? fileStorage.defaultNestPath
        )

        var logger = Logger(label: "com.github.mtj0928.nest")
        logger.logLevel = logLevel
        logger.debug("NEST_PATH: \(nestDirectory.rootDirectory.path()).")

        return Configuration(
            urlSession: urlSession,
            fileStorage: fileStorage,
            fileDownloader: NestFileDownloader(urlSession: urlSession, fileStorage: fileStorage),
            workingDirectory: fileStorage.temporaryDirectory.appending(path: "nest"),
            nestDirectory: nestDirectory,
            artifactBundleManager: ArtifactBundleManager(fileStorage: fileStorage, directory: nestDirectory),
            logger: logger
        )
    }
}

extension FileStorage {
    var defaultNestPath: URL {
        homeDirectoryForCurrentUser.appending(component: ".nest")
    }
}

extension ProcessInfo {
    var nestPath: String? {
        environment["NEST_PATH"]
    }
}
