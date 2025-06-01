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
    var verbose = false
    
    @Flag(help: "Will not perform installation.")
    var noInstall = false
    
    @Option(help: "A path to nestfile", completion: .file(extensions: ["yaml"]))
    var nestfilePath = "nestfile.yaml"

    @Argument(parsing: .captureForPassthrough)
    var arguments: [String]

    mutating func run() async throws {
        if arguments.first == "--help" {
            let helpMessage = Self.helpMessage(for: Self.self)
            print(helpMessage)
            return
        }

        let nestfile: Nestfile
        do {
            nestfile = try Nestfile.load(from: nestfilePath, fileSystem: FileManager.default)
        } catch {
            print("Nestfile not found at \(nestfilePath)".red)
            return
        }

        let (nestfileController, executableBinaryPreparer, nestDirectory, logger) = setUp(nestfile: nestfile)

        let subcommand: SubCommandOfRunCommand
        do {
            subcommand = try SubCommandOfRunCommand(arguments: arguments)
        } catch .emptyArguments {
            logger.error("`owner/repository` is not specified.", metadata: .color(.red))
            return
        } catch .invalidFormat {
            logger.error("Invalid format: \"\(arguments[0])\", expected owner/repository", metadata: .color(.red))
            return
        }

        guard let target = nestfileController.target(matchingTo: subcommand.repository, in: nestfile),
              let expectedVersion = target.version
        else {
            // While we could execute with the latest version, the bootstrap subcommand serves that purpose.
            // Therefore, we return an error when no version is specified.
            logger.error("Failed to find an expected version for \"\(arguments[0])\" in nestfile", metadata: .color(.red))
            return
        }

        let version = GitVersion.tag(expectedVersion)
        let executables: [ExecutableBinary]
        let installedBinaries = executableBinaryPreparer.resolveInstalledExecutableBinariesFromNestInfo(for: subcommand.repository, version: version)
        if !installedBinaries.isEmpty {
            executables = installedBinaries
        } else if noInstall {
            logger.error("The executable binary is not installed yet. Please try without the --no-install option or run the bootstrap command.", metadata: .color(.red))
            return
        } else {
            logger.info("Install executable binaries because they are not installed.")
            try await executableBinaryPreparer.installBinaries(
                gitURL: subcommand.repository,
                version: version,
                assetName: target.assetName,
                checksumOption: ChecksumOption(expectedChecksum: target.checksum, logger: logger)
            )
            executables = executableBinaryPreparer.resolveInstalledExecutableBinariesFromNestInfo(for: subcommand.repository, version: version)
        }

        guard !executables.isEmpty else {
            logger.error("No executable binary found.")
            return
        }

        // FIXME: Needs to address multiple commands in the same artifact bundle.
        let binaryRelativePath = executables[0].binaryPath.path(percentEncoded: false)
        let command = nestDirectory.rootDirectory.appending(path: binaryRelativePath).path(percentEncoded: false)
        var environment = ProcessInfo.processInfo.environment
        environment["RESOURCE_PATH"] = ""
        let result = try await NestProcessExecutor(environment: environment, logger: logger, logLevel: .info)
            .executeInteractively(command: command, subcommand.arguments)
        if result != 0 {
            Foundation.exit(result)
        }
    }
}

extension RunCommand {
    private func setUp(nestfile: Nestfile) -> (
        NestfileController,
        ExecutableBinaryPreparer,
        NestDirectory,
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
            configuration.logger
        )
    }
}
