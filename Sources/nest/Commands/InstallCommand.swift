import ArgumentParser
import Foundation
import Logging
import NestCLI
import NestKit

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

    @Option(name: .customLong("checksum-policy"), help: "Policy for artifact bundles without a checksum: skip, warn, or require.")
    var missingChecksumPolicy: MissingChecksumPolicyArgument?

    @OptionGroup
    var cacheOptions: CacheOptions

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let (executableBinaryPreparer, nestDirectory, artifactBundleManager, logger) = setUp()
        do {
            let resolvedMissingChecksumPolicy = missingChecksumPolicy?.policy ?? ProcessInfo.processInfo.missingChecksumPolicy
            let isMissingChecksumPolicyExplicit = missingChecksumPolicy != nil
            // Direct artifact bundle URLs always download a ZIP, so the user must
            // make a verification decision up front. A git target may build from
            // source instead, so a required-checksum failure remains deferred until
            // an artifact bundle ZIP is selected.
            if case .artifactBundle(let url) = target {
                _ = try URL.httpsURL(from: url.absoluteString)
                if requiresExplicitChecksumDecision(isMissingChecksumPolicyExplicit: isMissingChecksumPolicyExplicit) {
                    logger.error(
                        """
                        Installing a direct artifact bundle URL requires integrity verification.
                        Pass --checksum <value> to verify, or --checksum-policy <skip|warn|require> to choose explicitly.
                        """,
                        metadata: .color(.red)
                    )
                    Foundation.exit(1)
                }
            }

            let checksumOption = checksumOption(
                missingChecksumPolicy: resolvedMissingChecksumPolicy,
                isMissingChecksumPolicyExplicit: isMissingChecksumPolicyExplicit,
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
    func requiresExplicitChecksumDecision(isMissingChecksumPolicyExplicit: Bool) -> Bool {
        checksum == nil && !isMissingChecksumPolicyExplicit
    }

    func checksumOption(
        missingChecksumPolicy: MissingChecksumPolicy,
        isMissingChecksumPolicyExplicit: Bool,
        logger: Logger
    ) -> ChecksumOption {
        if let checksum {
            return .needsCheck(expected: checksum)
        }
        return switch missingChecksumPolicy {
        case .skip:
            .skip
        case .warn:
            .printActual { checksum in
                let message = "ℹ️ The checksum is \(checksum). Please use --checksum to verify the downloaded file."
                if isMissingChecksumPolicyExplicit {
                    logger.warning("\(message)")
                } else {
                    logger.info("\(message)")
                }
            }
        case .require:
            .unresolvable(.missingInstallChecksum(target: target.identifier))
        }
    }
}

extension InstallTarget {
    var identifier: String {
        switch self {
        case .git(let gitURL):
            gitURL.reference ?? gitURL.stringURL
        case .artifactBundle(let url):
            url.absoluteString
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
            logLevel: verbose ? .trace : .info,
            enableUserScopeCache: cacheOptions.enableUserScopeCache
        )

        return (
            configuration.executableBinaryPreparer,
            configuration.nestDirectory,
            configuration.artifactBundleManager,
            configuration.logger
        )
    }
}
