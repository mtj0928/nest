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

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        LoggingSystem.bootstrap()
        Configuration.default.logger.logLevel = verbose ? .trace : .info

        try nestFileManager.uninstall(command: commandName)
    }
}

extension UninstallCommand {
    var executableBinaryPreparer: ExecutableBinaryPreparer { Configuration.default.executableBinaryPreparer }
    var nestFileManager: NestFileManager { Configuration.default.nestFileManager }
    var logger: Logger { Configuration.default.logger }
}
