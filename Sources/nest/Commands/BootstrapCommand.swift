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

    @Argument(help: "A nestfile written in yaml.")
    var nestfilePath: String

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let nestfile = try Nestfile.load(from: nestfilePath, fileSystem: FileManager.default)

        let (executableBinaryPreparer, artifactBundleManager, logger) = setUp(nestPath: nestfile.nestPath)

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
                    version: version,
                    artifactBundleZipFileName: targetInfo.resolveAssetName()
                )
            case .artifactBundle(let url):
                logger.info("🔎 Start \(url.absoluteString)")
                executableBinaries = try await executableBinaryPreparer.fetchArtifactBundle(at: url)
            }

            for binary in executableBinaries {
                try artifactBundleManager.install(binary)
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
        case .zip(let zipURL):
            guard let parsedTarget = InstallTarget(argument: zipURL.url) else {
                return .failure(ParseError(contents: zipURL.url))
            }
            return .success(parsedTarget)
        }
    }

    func resolveVersion() -> String? {
        switch self {
        case .repository(let repository):
            return repository.version
        case .zip:
            return nil
        }
    }

    func resolveAssetName() -> String? {
        switch self {
        case .repository(let repository): repository.assetName
        case .zip: nil
        }
    }
}

extension BootstrapCommand {
    private func setUp(nestPath: String?) -> (
        ExecutableBinaryPreparer,
        ArtifactBundleManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: nestPath ?? ProcessInfo.processInfo.nestPath,
            logLevel: verbose ? .trace : .info
        )

        return (
            configuration.executableBinaryPreparer,
            configuration.artifactBundleManager,
            configuration.logger
        )
    }
}
