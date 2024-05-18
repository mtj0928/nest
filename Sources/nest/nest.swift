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
            BootstrapCommand.self
        ]
    )
}

extension Configuration {
    static func make(
        nestPath: String?,
        logLevel: Logger.Level,
        urlSession: URLSession = .shared,
        fileManager: FileManager = .default
    ) -> Configuration {
        let nestDirectory = NestDirectory(
            rootDirectory: nestPath.map { URL(filePath: $0) } ?? fileManager.defaultNeonPath
        )

        var logger = Logger(label: "com.github.mtj0928.nest")
        logger.logLevel = logLevel
        logger.debug("NEST_PATH: \(nestDirectory.rootDirectory.path()).")

        return Configuration(
            urlSession: urlSession,
            fileManager: fileManager,
            zipFileDownloader: ZipFileDownloader(urlSession: urlSession, fileManager: fileManager),
            workingDirectory: fileManager.temporaryDirectory.appending(path: "nest"),
            nestDirectory: nestDirectory,
            nestFileManager: NestFileManager(fileManager: fileManager, directory: nestDirectory),
            logger: logger
        )
    }
}

extension FileManager {
    var defaultNeonPath: URL {
        homeDirectoryForCurrentUser.appending(component: ".nest")
    }
}

extension ProcessInfo {
    var nesPath: String? {
        environment["NEST_PATH"]
    }
}
