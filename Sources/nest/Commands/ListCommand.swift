import ArgumentParser
import Foundation
import NestCLI
import NestKit
import Logging

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show all installed binaries "
    )

    @Flag(name: .shortAndLong, help: "Show a source of a binary.")
    var source: Bool = false

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        LoggingSystem.bootstrap()
        Configuration.default.logger.logLevel = verbose ? .trace : .info

        let installedCommands = nestFileManager.list()
        for (name, commands) in installedCommands {
            logger.info("\(name)")
            for command in commands {
                logger.info("  \(command.version) \(source ? command.source : "") \(command.isLinked ? "(Selected)".green : "")")
            }
        }
    }
}

extension ListCommand {
    var nestFileManager: NestFileManager { Configuration.default.nestFileManager }
    var logger: Logger { Configuration.default.logger }
}

extension NestInfo.Command {
    var source: String {
        switch manufacturer {
        case .artifactBundle(let sourceInfo):
            sourceInfo.repository?.reference.stringURL ?? sourceInfo.zipURL.absoluteString
        case .localBuild(let repository):
            repository.reference.stringURL
        }
    }
}
