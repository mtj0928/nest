import ArgumentParser
import Foundation
import Logging
import NestCLI
import NestKit

struct BootstrapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bootstrap",
        abstract: "Install repositories based on a given nestfile and update the selected command versions."
    )

    @Argument(help: "A nestfile written in yaml.")
    var nestfilePath: String

    @Option(name: .customLong("checksum-policy"), help: "Policy for artifact bundles without a checksum: skip, warn, or require.")
    var missingChecksumPolicy: MissingChecksumPolicyArgument?

    @Flag(name: [.customLong("skip-checksum-validation"), .customShort("s")], help: .hidden)
    var skipChecksumValidation = false

    @OptionGroup
    var cacheOptions: CacheOptions

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        let nestfile = try Nestfile.load(from: nestfilePath, fileSystem: FileManager.default)
        let (executableBinaryPreparer, artifactBundleManager, logger) = setUp(nestfile: nestfile)
        let resolvedMissingChecksumPolicy = if skipChecksumValidation {
            MissingChecksumPolicy.skip
        } else {
            missingChecksumPolicy?.policy ?? ProcessInfo.processInfo.missingChecksumPolicy
        }

        if nestfile.targets.contains(where: { $0.isDeprecatedZIP }) {
            logger.warning("""
                ⚠️ The format `- {URL}` for targets is deprecated and will be removed in a future release.
                Please update to thew new format `- zipURL: {URL}`.
                """, metadata: .color(.yellow)
            )
        }

        for targetInfo in nestfile.targets {
            let target: InstallTarget
            var version: GitVersion
            let checksumOption = targetInfo.checksumOption(missingChecksumPolicy: resolvedMissingChecksumPolicy)

            switch (targetInfo.resolveInstallTarget(), targetInfo.resolveVersion()) {
            case (.failure(let error), _):
                logger.error("Invalid input: \(error.contents)", metadata: .color(.red))
                return
            case (.success(let installTarget), let resolvedVersion):
                target = installTarget
                version = if let resolvedVersion { .tag(resolvedVersion) }
                else { .latestRelease }
            }

            let executableBinaries: [PreparedBinary]
            switch target {
            case .git(let gitURL):
                let versionString = version == .latestRelease ? "" : "(\(version.description)) "
                logger.info("🔎 Found \(gitURL.repositoryName) \(versionString)")
                executableBinaries = try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(
                    at: gitURL,
                    version: version,
                    artifactBundleZipFileName: targetInfo.assetName,
                    checksum: checksumOption
                )
            case .artifactBundle(let url):
                logger.info("🔎 Start \(url.absoluteString)")
                executableBinaries = try await executableBinaryPreparer.fetchArtifactBundle(at: url, checksum: checksumOption)
            }

            for binary in executableBinaries {
                let executableBinary = binary.executableBinary
                if binary.isAlreadyInstalled {
                    try artifactBundleManager.link(executableBinary)
                } else {
                    try artifactBundleManager.install(executableBinary)
                }
                logger.info("🪺 Success to install \(executableBinary.commandName).", metadata: .color(.green))
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
            guard let parsedTarget = InstallTarget(argument: zipURL.zipURL) else {
                return .failure(ParseError(contents: zipURL.zipURL))
            }
            return .success(parsedTarget)
        case .deprecatedZIP(let zipURL):
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
        case .zip, .deprecatedZIP:
            return nil
        }
    }
}

extension BootstrapCommand {
    private func setUp(nestfile: Nestfile) -> (
        ExecutableBinaryPreparer,
        ArtifactBundleManager,
        Logger
    ) {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: nestfile.nestPath ?? ProcessInfo.processInfo.nestPath,
            registryTokenEnvironmentVariableNames: nestfile.registries?.githubServerTokenEnvironmentVariableNames ?? [:],
            logLevel: verbose ? .trace : .info,
            enableUserScopeCache: cacheOptions.enableUserScopeCache
        )

        return (
            configuration.executableBinaryPreparer,
            configuration.artifactBundleManager,
            configuration.logger
        )
    }
}
