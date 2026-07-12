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

    @Option(help: "Checksum validation policy for downloaded artifact bundles: skip, warn, or require.")
    var checksumPolicy: ChecksumValidationPolicyArgument?

    @OptionGroup
    var cacheOptions: CacheOptions

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let (executableBinaryPreparer, nestDirectory, artifactBundleManager, logger) = setUp()
        do {
            let checksumValidationPolicy = checksumPolicy?.policy ?? ProcessInfo.processInfo.checksumValidationPolicy
            let isChecksumPolicyExplicit = checksumPolicy != nil
            // Direct artifact bundle URLs always download a ZIP, so the user must
            // make a verification decision up front. The git path may build from
            // source instead, so any checksum-flag inconsistency is deferred to
            // `.unresolvable` and only surfaces if a ZIP is actually downloaded.
            if case .artifactBundle(let url) = target {
                _ = try URL.httpsURL(from: url.absoluteString)
                if requiresExplicitChecksumDecision(isChecksumPolicyExplicit: isChecksumPolicyExplicit) {
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
                checksumValidationPolicy: checksumValidationPolicy,
                isChecksumPolicyExplicit: isChecksumPolicyExplicit,
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
    func requiresExplicitChecksumDecision(isChecksumPolicyExplicit: Bool) -> Bool {
        checksum == nil && !isChecksumPolicyExplicit
    }

    func checksumOption(
        checksumValidationPolicy: ChecksumValidationPolicy,
        isChecksumPolicyExplicit: Bool,
        logger: Logger
    ) -> ChecksumOption {
        if checksum != nil && checksumValidationPolicy == .skip {
            return .unresolvable(.mutuallyExclusiveFlags)
        }
        if checksum == nil && checksumValidationPolicy == .require {
            return .unresolvable(.missingInstallChecksum(target: target.identifier))
        }
        if checksum == nil && checksumValidationPolicy == .warn && isChecksumPolicyExplicit {
            return .printActual { checksum in
                logger.warning("ℹ️ The checksum is \(checksum). Please use --checksum to verify the downloaded file.")
            }
        }
        return ChecksumOption(
            isSkip: checksumValidationPolicy == .skip,
            expectedChecksum: checksum,
            logger: logger
        )
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
