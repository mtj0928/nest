import ArgumentParser
import Foundation
import NestCLI
import NestKit
import Logging

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install a repository"
    )

    @Argument(help: """
        A git repository or a URL of an artifactbunlde you want to install. (e.g., `owner/repository`, `https://github.com/...`, and `https://examaple.com/../foo.artifactbundle.zip`)
        """)
    var target: InstallTarget

    @Argument
    var version: GitVersion = .latestRelease

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let (executableBinaryPreparer, nestDirectory, nestFileManager, logger) = setUp()
        do {

            let executableBinaries = switch target {
            case .git(let gitURL):
                try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(at: gitURL, version: version)
            case .artifactBundle(let url):
                try await executableBinaryPreparer.fetchArtifactBundle(at: url)
            }

            for binary in executableBinaries {
                try nestFileManager.install(binary)
                logger.info("🪺 Success to install \(binary.commandName).", metadata: .color(.green))
            }

            let binDirectory = nestDirectory.bin.path()
            let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map { String($0) } ?? []
            if ProcessInfo.processInfo.nesPath?.isEmpty ?? true,
               !path.contains(binDirectory) {
                logger.warning("\(binDirectory) is not added to $PATH.", metadata: .color(.yellow))
            }
        } catch {
            logger.error(error)
            Foundation.exit(1)
        }
    }
}

extension InstallCommand {
    private func setUp() -> (
        ExecutableBinaryPreparer,
        NestDirectory,
        NestFileManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: ProcessInfo.processInfo.nesPath,
            logLevel: verbose ? .trace : .info
        )

        return (
            configuration.executableBinaryPreparer,
            configuration.nestDirectory,
            configuration.nestFileManager,
            configuration.logger
        )
    }
}
