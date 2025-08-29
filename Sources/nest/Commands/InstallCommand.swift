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
        let (executableBinaryPreparer, nestDirectory, artifactBundleManager, logger) = setUp()
        do {

            let executableBinaries: [PreparedBinary] = switch target {
            case .git(let gitURL):
                try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(
                    at: gitURL,
                    version: version,
                    artifactBundleZipFileName: nil,
                    checksum: .skip
                )
            case .artifactBundle(let url):
                try await executableBinaryPreparer.fetchArtifactBundle(at: url, checksum: .skip)
            }

            for binary in executableBinaries {
                let executableBinary = binary.executableBinary
                if binary.isAlreadyInstalled {
                    logger.info("🪺 Skip to install \(binary.executableBinary) because it's already installed .", metadata: .color(.green))
                } else {
                    try artifactBundleManager.install(executableBinary)
                    logger.info("🪺 Success to install \(executableBinary.commandName).", metadata: .color(.green))
                }
            }

            let binDirectory = nestDirectory.bin.path()
            let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map { String($0) } ?? []
            if ProcessInfo.processInfo.nestPath?.isEmpty ?? true,
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
        ArtifactBundleManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: ProcessInfo.processInfo.nestPath,
            logLevel: verbose ? .trace : .info
        )

        return (
            configuration.executableBinaryPreparer,
            configuration.nestDirectory,
            configuration.artifactBundleManager,
            configuration.logger
        )
    }
}
