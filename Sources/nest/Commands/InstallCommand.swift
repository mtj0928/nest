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

    @Option(help: "Verify the downloaded artifact bundle against this checksum.")
    var checksum: String?

    @Flag(help: "Skip checksum verification. Required when installing a direct artifact bundle URL without --checksum.")
    var allowUnverified = false

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let (executableBinaryPreparer, nestDirectory, artifactBundleManager, logger) = setUp()
        do {
            if checksum != nil && allowUnverified {
                logger.error("--checksum and --allow-unverified are mutually exclusive.", metadata: .color(.red))
                Foundation.exit(1)
            }
            if case .artifactBundle = target, checksum == nil, !allowUnverified {
                logger.error(
                    """
                    Installing a direct artifact bundle URL requires integrity verification.
                    Pass --checksum <value> to verify, or --allow-unverified to skip explicitly.
                    """,
                    metadata: .color(.red)
                )
                Foundation.exit(1)
            }

            let checksumOption = ChecksumOption(
                isSkip: allowUnverified,
                expectedChecksum: checksum,
                logger: logger
            )

            let executableBinaries: [PreparedBinary] = switch target {
            case .git(let gitURL):
                try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(
                    at: gitURL,
                    version: version,
                    artifactBundleZipFileName: nil,
                    checksum: checksumOption
                )
            case .artifactBundle(let url):
                try await executableBinaryPreparer.fetchArtifactBundle(at: url, checksum: checksumOption)
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
