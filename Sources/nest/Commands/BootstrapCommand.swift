import ArgumentParser
import Foundation
import NestCLI
import NestKit
import Logging

struct BootstrapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bootstrap",
        abstract: "Install repositories based on a given nestfile."
    )

    @Argument(help: "A nestfile written in pkl.")
    var nestfilePath: String

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let nestfile = try await Nestfile.loadFrom(source: .path(nestfilePath))

        let (executableBinaryPreparer, nestFileManager, logger) = setUp(nestPath: nestfile.nestPath)

        for targetInfo in nestfile.targets {
            let target: InstallTarget
            var version: GitVersion

            switch (targetInfo.resolveInstallTarget(), targetInfo.resolveVersion()) {
            case (.failure(let error), _):
                logger.error("Invalid input: \(error.contents)", metadata: .color(.red))
                return
            case (.success(let installTarget), let resolvedVersion):
                target = installTarget
                version = if let resolvedVersion { .tag(resolvedVersion) }
                else { .latestRelease }
            }

            let executableBinaries: [ExecutableBinary]
            switch target {
            case .git(let gitURL):
                let versionString = version == .latestRelease ? "" : "(\(version.description)) "
                logger.info("🔎 Found \(gitURL.repositoryName) \(versionString)")
                executableBinaries = try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(
                    at: gitURL,
                    version: version
                )
            case .artifactBundle(let url):
                logger.info("🔎 Start \(url.absoluteString)")
                executableBinaries = try await executableBinaryPreparer.fetchArtifactBundle(at: url)
            }

            for binary in executableBinaries {
                try nestFileManager.install(binary)
                logger.info("🪺 Success to install \(binary.commandName).", metadata: .color(.green))
            }
        }
    }
}

extension Nestfile.Target {
    struct ParseError: Error {
        let contents: String
    }

    func resolveInstallTarget() -> Result<InstallTarget, ParseError> {
        switch self {
        case .repository(let repository):
            guard let parsedTarget = InstallTarget(argument: repository.reference) else {
                return .failure(ParseError(contents: repository.reference))
            }
            return .success(parsedTarget)
        case .zipUrl(let zipURL):
            guard let parsedTarget =  InstallTarget(argument: zipURL) else {
                return .failure(ParseError(contents: zipURL))
            }
            return .success(parsedTarget)
        }
    }

    func resolveVersion() -> String? {
        switch self {
        case .repository(let repository):
            return repository.version
        case .zipUrl:
            return nil
        }
    }
}

extension BootstrapCommand {
    private func setUp(nestPath: String?) -> (
        ExecutableBinaryPreparer,
        NestFileManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: nestPath ?? ProcessInfo.processInfo.nestPath,
            logLevel: verbose ? .trace : .info
        )

        return (
            configuration.executableBinaryPreparer,
            configuration.nestFileManager,
            configuration.logger
        )
    }
}
