import ArgumentParser
import AsyncOperations
import Foundation
import NestCLI
import NestKit
import Logging

struct ResolveNestfileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resolve-nestfile",
        abstract: "Overwrite the nestfile with the latest versions if a version is not specified."
    )

    @Argument(help: "A nestfile written in yaml.")
    var nestfilePath: String

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let nestfile = try Nestfile.load(from: nestfilePath, fileSystem: FileManager.default)
        let (controller, fileSystem, logger) = setUp(nestfile: nestfile)
        let updatedNestfile = try await controller.resolve(nestfile)
        try updatedNestfile.write(to: nestfilePath, fileSystem: fileSystem)
        logger.info("✨ \(URL(filePath: nestfilePath).lastPathComponent) is Updated")
    }
}

extension ResolveNestfileCommand {
    private func setUp(nestfile: Nestfile) -> (NestfileController, any FileSystem, Logger) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: nestfile.nestPath ?? ProcessInfo.processInfo.nestPath,
            serverTokenEnvironmentVariableNames: nestfile.servers?.githubServerTokenEnvironmentVariableNames ?? [:],
            logLevel: verbose ? .trace : .info
        )
        let controller = NestfileController(
            repositoryClientBuilder: GitRepositoryClientBuilder(
                httpClient: configuration.httpClient,
                serverConfigs: .resolve(environmentVariableNames: nestfile.servers?.githubServerTokenEnvironmentVariableNames ?? [:]),
                logger: configuration.logger
            ),
            fileSystem: configuration.fileSystem,
            fileDownloader: configuration.fileDownloader,
            checksumCalculator: SwiftChecksumCalculator(swift: SwiftCommand(
                executor: NestProcessExecutor(logger: configuration.logger)
            ))
        )
        return (controller, configuration.fileSystem, configuration.logger)
    }
}
