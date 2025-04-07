import ArgumentParser
import AsyncOperations
import Foundation
import NestCLI
import NestKit
import Logging

struct UpdateNestfileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update-nestfile",
        abstract: "Overwrite the nestfile with the latest versions."
    )

    @Argument(help: "A nestfile written in yaml.")
    var nestfilePath: String

    @Option(parsing: .upToNextOption, help: "Exclude by repository or version when using reference-only.\n(ex. --excludes owner/repo@0.0.1 owner/repo@0.0.2)")
    var excludes: [ExcludedTarget] = []

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let nestfile = try Nestfile.load(from: nestfilePath, fileSystem: FileManager.default)
        let (controller, fileSystem, logger) = setUp(nestfile: nestfile)
        let updatedNestfile = try await controller.update(nestfile, excludedTargets: excludes)
        try updatedNestfile.write(to: nestfilePath, fileSystem: fileSystem)
        logger.info("✨ \(URL(filePath: nestfilePath).lastPathComponent) is Updated")
    }
}

extension UpdateNestfileCommand {
    private func setUp(nestfile: Nestfile) -> (NestfileController, any FileSystem, Logger) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: nestfile.nestPath ?? ProcessInfo.processInfo.nestPath,
            registryTokenEnvironmentVariableNames: nestfile.registries?.githubServerTokenEnvironmentVariableNames ?? [:],
            logLevel: verbose ? .trace : .info
        )
        let controller = NestfileController(
            assetRegistryClientBuilder: AssetRegistryClientBuilder(
                httpClient: configuration.httpClient,
                registryConfigs: RegistryConfigs(github: GitHubRegistryConfigs.resolve(environmentVariableNames: nestfile.registries?.githubServerTokenEnvironmentVariableNames ?? [:])),
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
