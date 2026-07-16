import NestCLI
import Testing

struct NestfileTargetChecksumOptionTests {
    @Test(arguments: [MissingChecksumPolicy.skip, .warn, .require])
    func checksumOptionNeedsCheckWhenChecksumExists(missingChecksumPolicy: MissingChecksumPolicy) {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: "abc123"))

        switch target.checksumOption(missingChecksumPolicy: missingChecksumPolicy) {
        case .needsCheck(let expected):
            #expect(expected == "abc123")
        default:
            Issue.record("Expected .needsCheck")
        }
    }

    @Test
    func checksumOptionWarnsWhenChecksumIsMissing() {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: nil))

        switch target.checksumOption(missingChecksumPolicy: .warn) {
        case .warnOnMissingChecksum(let targetIdentifier):
            #expect(targetIdentifier == "owner/repo")
        default:
            Issue.record("Expected .warnOnMissingChecksum")
        }
    }

    @Test
    func checksumOptionIsUnresolvableWhenChecksumIsRequiredButMissing() {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: nil))

        switch target.checksumOption(missingChecksumPolicy: .require) {
        case .unresolvable(.missingChecksum(let targetIdentifier)):
            #expect(targetIdentifier == "owner/repo")
        default:
            Issue.record("Expected .unresolvable(.missingChecksum)")
        }
    }

    @Test
    func checksumOptionSkipsWhenMissingChecksumPolicySkips() {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: nil))

        switch target.checksumOption(missingChecksumPolicy: .skip) {
        case .skip:
            break
        default:
            Issue.record("Expected .skip")
        }
    }
}
