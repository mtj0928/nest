import Logging
import Testing
@testable import nest

struct ChecksumPolicyCommandArgumentsTests {
    @Test
    func runCommandAcceptsChecksumPolicy() throws {
        let command = try RunCommand.parse(["--checksum-policy", "require", "owner/repo"])

        #expect(command.checksumPolicy == .require)
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

        #expect(command.checksumPolicy == .warn)
    }

    @Test
    func installCommandAcceptsExplicitWarnPolicyForDirectArtifactBundleURL() throws {
        let command = try InstallCommand.parse([
            "https://example.com/foo.artifactbundle.zip",
            "--checksum-policy",
            "warn"
        ])

        #expect(command.checksumPolicy == .warn)
        #expect(!command.requiresExplicitChecksumDecision(isChecksumPolicyExplicit: true))
    }

    @Test
    func installCommandStillRequiresExplicitChecksumDecisionForDirectArtifactBundleURL() throws {
        let command = try InstallCommand.parse(["https://example.com/foo.artifactbundle.zip"])

        #expect(command.requiresExplicitChecksumDecision(isChecksumPolicyExplicit: false))
    }

    @Test
    func installCommandUsesInstallSpecificMissingChecksumError() throws {
        let command = try InstallCommand.parse([
            "https://example.com/foo.artifactbundle.zip",
            "--checksum-policy",
            "require"
        ])

        switch command.checksumOption(
            checksumValidationPolicy: .require,
            isChecksumPolicyExplicit: true,
            logger: Logger(label: "test")
        ) {
        case .unresolvable(.missingInstallChecksum(let target)):
            #expect(target == "https://example.com/foo.artifactbundle.zip")
        default:
            Issue.record("Expected .unresolvable(.missingInstallChecksum)")
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

        #expect(command.checksumPolicy == nil)
        #expect(command.arguments == ["--require-checksum", "owner/repo"])
    }

    @Test
    func bootstrapCommandRejectsUnreleasedRequireChecksumFlag() {
        #expect(throws: (any Error).self) {
            try BootstrapCommand.parse(["nestfile.yaml", "--require-checksum"])
        }
    }
}
