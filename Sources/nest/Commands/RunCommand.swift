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
        
        guard !arguments.isEmpty else {
            logger.error("`owner/repository` is not specified.", metadata: .color(.red))
            return
        }
        guard arguments[0].contains("/") else {
            logger.error("Invalid format: \(arguments), expected owner/repository", metadata: .color(.red))
            return
        }
        
        let reference = arguments[0]
        let subcommands: [String] = if arguments.count >= 2 {
            Array(arguments[1...])
        } else {
            []
        }
        guard let target = nestfileController.target(matchingTo: reference, in: nestfile),
              let expectedVersion = target.version
        else {
            // While we could execute with the latest version, the bootstrap subcommand serves that purpose.
            // Therefore, we return an error when no version is specified.
            logger.error("Failed to find expected version in nestfile", metadata: .color(.red))
            return
        }
        
        guard let installTarget = InstallTarget(argument: reference),
              case let .git(gitURL) = installTarget,
              let gitVersion = GitVersion(argument: expectedVersion)
        else {
            return
        }

        guard let binaryRelativePath = try await resolveBinaryRelativePath(
            didAttemptInstallation: false,
            noInstall: noInstall,
            reference: reference,
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
                subcommands
            )
    }

    private func resolveBinaryRelativePath(
        didAttemptInstallation: Bool,
        noInstall: Bool,
        reference: String,
        version: String,
        target: Nestfile.Target,
        gitURL: GitURL,
        gitVersion: GitVersion,
        nestInfoController: NestInfoController,
        executableBinaryPreparer: ExecutableBinaryPreparer,
        artifactBundleManager: ArtifactBundleManager,
        logger: Logger
    ) async throws -> String? {
        guard let binaryRelativePath = nestInfoController.command(matchingTo: reference, version: version)?.binaryPath
        else {
            // attempt installation only once
            guard !didAttemptInstallation && !noInstall else { return nil }
            
            let checksumOption = ChecksumOption(expectedChecksum: target.resolveChecksum(), logger: logger)
            
            let executableBinaries = try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(
                at: gitURL,
                version: gitVersion,
                artifactBundleZipFileName: target.resolveAssetName(),
                checksum: checksumOption
            )

            for binary in executableBinaries {
                try artifactBundleManager.install(binary)
                logger.info("🪺 Success to install \(binary.commandName) version \(binary.version).")
            }

            return try await resolveBinaryRelativePath(
                didAttemptInstallation: true,
                noInstall: noInstall,
                reference: reference,
                version: version,
                target: target,
                gitURL: gitURL,
                gitVersion: gitVersion,
                nestInfoController: nestInfoController,
                executableBinaryPreparer: executableBinaryPreparer,
                artifactBundleManager: artifactBundleManager,
                logger: logger
            )
        }
        return binaryRelativePath
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
