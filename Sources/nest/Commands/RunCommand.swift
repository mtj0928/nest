import ArgumentParser
import Foundation
import NestKit
import NestCLI
import Logging

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run executable file on a given nestfile. If not found, it will attempt to install."
    )

    @Flag(name: .shortAndLong)
    var verbose: Bool = false
    
    @Flag(help: "Will not perform installation.")
    var noInstall: Bool = false
    
    @Option(help: "A path to nestfile")
    var nestfilePath: String = "nestfile.yaml"
    
    @Argument(parsing: .captureForPassthrough)
    var arguments: [String]
    
    mutating func run() async throws {
        let nestfile = try Nestfile.load(from: nestfilePath, fileSystem: FileManager.default)
        let (nestfileController, executableBinaryPreparer, nestDirectory, artifactBundleManager, logger) = setUp(nestfile: nestfile)
        let nestInfoController = NestInfoController(directory: nestDirectory, fileSystem: FileManager.default)
        
        let executor: RunCommandExecutor
        do {
            executor = try RunCommandExecutor(arguments: arguments)
        } catch let error as RunCommandExecutor.ParseError {
            switch error {
            case .emptyArguments:
                logger.error("`owner/repository` is not specified.", metadata: .color(.red))
            case .invalidFormat:
                logger.error("Invalid format: \(arguments), expected owner/repository", metadata: .color(.red))
            }
            return
        }

        guard let target = nestfileController.target(matchingTo: executor.reference, in: nestfile),
              let expectedVersion = target.version
        else {
            // While we could execute with the latest version, the bootstrap subcommand serves that purpose.
            // Therefore, we return an error when no version is specified.
            logger.error("Failed to find expected version in nestfile", metadata: .color(.red))
            return
        }

        guard let installTarget = InstallTarget(argument: executor.reference),
              case let .git(gitURL) = installTarget,
              let gitVersion = GitVersion(argument: expectedVersion)
        else {
            return
        }

        guard let binaryRelativePath = try await executor.resolveBinaryRelativePath(
            noInstall: noInstall,
            reference: executor.reference,
            version: expectedVersion,
            target: target,
            gitURL: gitURL,
            gitVersion: gitVersion,
            nestInfoController: nestInfoController,
            executableBinaryPreparer: executableBinaryPreparer,
            artifactBundleManager: artifactBundleManager,
            logger: logger
        ) else {
            logger.error(
                "Failed to find binary path, likely because it's not installed. Please try without the --no-install option or run the bootstrap command.",
                metadata: .color(.red)
            )
            return
        }

        _ = try await NestProcessExecutor(logger: logger, logLevel: .info)
            .execute(
                command: "\(nestDirectory.rootDirectory.relativePath)\(binaryRelativePath)",
                executor.subcommands
            )
    }
}

extension RunCommand {
    private func setUp(nestfile: Nestfile) -> (
        NestfileController,
        ExecutableBinaryPreparer,
        NestDirectory,
        ArtifactBundleManager,
        Logger
    ) {
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

        return (
            controller,
            configuration.executableBinaryPreparer,
            configuration.nestDirectory,
            configuration.artifactBundleManager,
            configuration.logger
        )
    }
}
