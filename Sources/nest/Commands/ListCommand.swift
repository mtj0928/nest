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

    @MainActor mutating func run() async throws {
        let (nestFileManager, logger) = setUp()

        let installedCommands = nestFileManager.list()
        for (name, commands) in installedCommands {
            logger.info("\(name)")
            for command in commands {
                let isLinked = nestFileManager.isLinked(name: name, commend: command)
                logger.info("  \(command.version) \(source ? command.source : "") \(isLinked ? "(Selected)".green : "")")
            }
        }
    }
}

extension ListCommand {
    private func setUp() -> (
        NestFileManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: ProcessInfo.processInfo.nesPath,
            logLevel: verbose ? .trace : .info
        )

        return (
            configuration.nestFileManager,
            configuration.logger
        )
    }
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
