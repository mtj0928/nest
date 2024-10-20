import ArgumentParser
import AsyncOperations
import Foundation
import NestCLI
import NestKit
import Logging

struct UpdateNestfileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update-nestfile",
        abstract: "Generates a sample nestfile into the current directory."
    )

    @Argument(help: "A nestfile written in yaml.")
    var nestfilePath: String

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let nestfile = try Nestfile.load(from: nestfilePath, fileSystem: FileManager.default)
        let (updater, fileSystem, logger) = setUp(nestfile: nestfile)
        let updatedNestfile = try await updater.update(nestfile)
        try updatedNestfile.write(to: nestfilePath, fileSystem: fileSystem)
        logger.info("✨ \(URL(filePath: nestfilePath).lastPathComponent) is Updated")
    }
}

extension UpdateNestfileCommand {
    private func setUp(nestfile: Nestfile) -> (NestfileUpdater, any FileSystem, Logger) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: nestfile.nestPath ?? ProcessInfo.processInfo.nestPath,
            logLevel: verbose ? .trace : .info
        )
        let updater = NestfileUpdater(
            repositoryClientBuilder: GitRepositoryClientBuilder(
                httpClient: configuration.httpClient,
                logger: configuration.logger
            ),
            fileSystem: configuration.fileSystem,
            fileDownloader: configuration.fileDownloader,
            checksumCalculator: SwiftChecksumCalculator(swift: SwiftCommand(
                executor: NestProcessExecutor(logger: configuration.logger)
            ))
        )
        return (updater, configuration.fileSystem, configuration.logger)
    }
}
