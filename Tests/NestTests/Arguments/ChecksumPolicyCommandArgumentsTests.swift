import Logging
import Testing
@testable import nest

struct ChecksumPolicyCommandArgumentsTests {
    @Test
    func runCommandAcceptsChecksumPolicy() throws {
        let command = try RunCommand.parse(["--checksum-policy", "require", "owner/repo"])

        #expect(command.missingChecksumPolicy == .require)
    }

    @Test
    func runCommandAcceptsReleasedSkipChecksumValidationAlias() throws {
        let command = try RunCommand.parse(["--skip-checksum-validation", "owner/repo"])

        #expect(command.skipChecksumValidation)
    }

    @Test
    func runCommandAcceptsReleasedShortSkipChecksumValidationAlias() throws {
        let command = try RunCommand.parse(["-s", "owner/repo"])

        #expect(command.skipChecksumValidation)
        #expect(command.arguments == ["owner/repo"])
    }

    @Test
    func bootstrapCommandAcceptsReleasedSkipChecksumValidationAlias() throws {
        let command = try BootstrapCommand.parse(["nestfile.yaml", "--skip-checksum-validation"])

        #expect(command.skipChecksumValidation)
    }

    @Test
    func bootstrapCommandAcceptsReleasedShortSkipChecksumValidationAlias() throws {
        let command = try BootstrapCommand.parse(["nestfile.yaml", "-s"])

        #expect(command.skipChecksumValidation)
    }

    @Test
    func installCommandAcceptsChecksumPolicy() throws {
        let command = try InstallCommand.parse(["owner/repo", "--checksum-policy", "warn"])

        #expect(command.missingChecksumPolicy == .warn)
    }

    @Test
    func installCommandAcceptsExplicitWarnPolicyForDirectArtifactBundleURL() throws {
        let command = try InstallCommand.parse([
            "https://example.com/foo.artifactbundle.zip",
            "--checksum-policy",
            "warn"
        ])

        #expect(command.missingChecksumPolicy == .warn)
        #expect(!command.requiresExplicitChecksumDecision(isMissingChecksumPolicyExplicit: true))
    }

    @Test
    func installCommandStillRequiresExplicitChecksumDecisionForDirectArtifactBundleURL() throws {
        let command = try InstallCommand.parse(["https://example.com/foo.artifactbundle.zip"])

        #expect(command.requiresExplicitChecksumDecision(isMissingChecksumPolicyExplicit: false))
    }

    @Test
    func installCommandUsesInstallSpecificMissingChecksumError() throws {
        let command = try InstallCommand.parse([
            "https://example.com/foo.artifactbundle.zip",
            "--checksum-policy",
            "require"
        ])

        switch command.checksumOption(
            missingChecksumPolicy: .require,
            isMissingChecksumPolicyExplicit: true,
            logger: Logger(label: "test")
        ) {
        case .unresolvable(.missingInstallChecksum(let target)):
            #expect(target == "https://example.com/foo.artifactbundle.zip")
        default:
            Issue.record("Expected .unresolvable(.missingInstallChecksum)")
        }
    }

    @Test(arguments: [MissingChecksumPolicyArgument.skip, .warn, .require])
    func installCommandChecksProvidedChecksumRegardlessOfPolicy(missingChecksumPolicyArgument: MissingChecksumPolicyArgument) throws {
        let command = try InstallCommand.parse([
            "owner/repo",
            "--checksum",
            "abc123"
        ])

        switch command.checksumOption(
            missingChecksumPolicy: missingChecksumPolicyArgument.policy,
            isMissingChecksumPolicyExplicit: true,
            logger: Logger(label: "test")
        ) {
        case .needsCheck(let expected):
            #expect(expected == "abc123")
        default:
            Issue.record("Expected .needsCheck")
        }
    }

    @Test
    func installCommandSkipsOnlyWhenChecksumIsMissing() throws {
        let command = try InstallCommand.parse(["owner/repo"])

        switch command.checksumOption(
            missingChecksumPolicy: .skip,
            isMissingChecksumPolicyExplicit: true,
            logger: Logger(label: "test")
        ) {
        case .skip:
            break
        default:
            Issue.record("Expected .skip")
        }
    }

    @Test
    func installCommandReportsActualChecksumWhenWarnPolicyAllowsMissingChecksum() throws {
        let command = try InstallCommand.parse(["owner/repo"])

        switch command.checksumOption(
            missingChecksumPolicy: .warn,
            isMissingChecksumPolicyExplicit: true,
            logger: Logger(label: "test")
        ) {
        case .printActual:
            break
        default:
            Issue.record("Expected .printActual")
        }
    }

    @Test(arguments: [
        ["owner/repo", "--allow-unverified"],
        ["owner/repo", "--require-checksum"]
    ])
    func installCommandRejectsUnreleasedChecksumFlags(arguments: [String]) {
        #expect(throws: (any Error).self) {
            try InstallCommand.parse(arguments)
        }
    }

    @Test
    func runCommandDoesNotRecognizeUnreleasedRequireChecksumFlag() throws {
        let command = try RunCommand.parse(["--require-checksum", "owner/repo"])

        #expect(command.missingChecksumPolicy == nil)
        #expect(command.arguments == ["--require-checksum", "owner/repo"])
    }

    @Test
    func bootstrapCommandRejectsUnreleasedRequireChecksumFlag() {
        #expect(throws: (any Error).self) {
            try BootstrapCommand.parse(["nestfile.yaml", "--require-checksum"])
        }
    }
}
