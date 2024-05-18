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
            var version: GitVersion = .latestRelease
            if let repositoryInfo = targetInfo as? Nestfile.Repository,
               let parsedTarget =  InstallTarget(argument: repositoryInfo.reference) {
                target = parsedTarget
                version = repositoryInfo.version.map(GitVersion.tag) ?? .latestRelease
            } else if let zipURL = targetInfo as? Nestfile.ZipUrl,
                      let parsedTarget =  InstallTarget(argument: zipURL) {
                target = parsedTarget
            } else {
                logger.error("Invalid input: \(targetInfo?.description ?? "")", metadata: .color(.red))
                return
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

extension BootstrapCommand {
    private func setUp(nestPath: String?) -> (
        ExecutableBinaryPreparer,
        NestFileManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: nestPath ?? ProcessInfo.processInfo.nesPath,
            logLevel: verbose ? .trace : .info
        )

        return (
            configuration.executableBinaryPreparer,
            configuration.nestFileManager,
            configuration.logger
        )
    }
}
