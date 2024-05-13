import ArgumentParser
import Foundation
import NestCLI
import NestKit
import Logging

struct UninstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Uninstall a repository"
    )

    @Argument(help: "A command name you want to uninstall.")
    var commandName: String

    @Argument(help: "A version you want to uninstall")
    var version: String?

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        LoggingSystem.bootstrap()
        Configuration.default.logger.logLevel = verbose ? .trace : .info

        let info = nestFileManager.list()

        let targetCommand = info[commandName, default: []].filter { command in
            command.version == version || version == nil
        }
        for command in targetCommand {
            try nestFileManager.uninstall(command: commandName, version: command.version)
            logger.info("🗑️ \(commandName) \(command.version) is uninstalled.")
        }
    }
}

extension UninstallCommand {
    var nestFileManager: NestFileManager { Configuration.default.nestFileManager }
    var logger: Logger { Configuration.default.logger }
}
