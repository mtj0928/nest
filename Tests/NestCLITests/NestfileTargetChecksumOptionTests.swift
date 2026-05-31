import NestCLI
import Testing

struct NestfileTargetChecksumOptionTests {
    @Test
    func checksumOptionNeedsCheckWhenChecksumExists() {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: "abc123"))

        switch target.checksumOption(policy: .warn) {
        case .needsCheck(let expected):
            #expect(expected == "abc123")
        default:
            Issue.record("Expected .needsCheck")
        }
    }

    @Test
    func checksumOptionIsUnresolvableWhenChecksumIsMissing() {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: nil))

        switch target.checksumOption(policy: .warn) {
        case .warnOnMissingChecksum(let targetIdentifier):
            #expect(targetIdentifier == "owner/repo")
        default:
            Issue.record("Expected .warnOnMissingChecksum")
        }
    }

    @Test
    func checksumOptionIsUnresolvableWhenChecksumIsMissingInStrictMode() {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: nil))

        switch target.checksumOption(policy: .require) {
        case .unresolvable(.missingChecksum(let targetIdentifier)):
            #expect(targetIdentifier == "owner/repo")
        default:
            Issue.record("Expected .unresolvable(.missingChecksum)")
        }
    }

    @Test
    func checksumOptionSkipsWhenValidationIsSkipped() {
        let target = Nestfile.Target.repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: nil))

        switch target.checksumOption(policy: .skip) {
        case .skip:
            break
        default:
            Issue.record("Expected .skip")
        }
    }
}
