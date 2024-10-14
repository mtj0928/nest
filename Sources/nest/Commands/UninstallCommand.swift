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
        let (nestFileManager, logger) = setUp()

        let info = nestFileManager.list()

        let targetCommand = info[commandName, default: []].filter { command in
            command.version == version || version == nil
        }

        guard !targetCommand.isEmpty else {
            if let version {
                logger.error("🪹 \(commandName) (\(version)) doesn't exist.", metadata: .color(.red))
            } else {
                logger.error("🪹 \(commandName) doesn't exist.", metadata: .color(.red))
            }
            Foundation.exit(1)
        }

        for command in targetCommand {
            try nestFileManager.uninstall(command: commandName, version: command.version)
            logger.info("🗑️ \(commandName) \(command.version) is uninstalled.")
        }
    }
}

extension UninstallCommand {
    private func setUp() -> (
        NestFileManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: ProcessInfo.processInfo.nestPath,
            logLevel: verbose ? .trace : .info
        )

        return (
            configuration.nestFileManager,
            configuration.logger
        )
    }
}
