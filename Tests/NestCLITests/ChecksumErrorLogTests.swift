import Foundation
import NestCLI
import Testing

struct ChecksumErrorLogTests {
    @Test(arguments: [
        ("https://credential-user:credential-password@example.com/foo.zip?token=token-secret#fragment-secret", "https://example.com/foo.zip"),
        ("https://example.com/foo.zip?custom=token-secret", "https://example.com/foo.zip"),
        ("http://credential-user:credential-password@example.com:8080/foo.zip?token=token-secret", "http://example.com:8080/foo.zip"),
        ("deployment_user@ghe.example.com:owner/repo.git", "ghe.example.com:owner/repo.git"),
        ("owner/repo", "owner/repo"),
        ("github.com/owner/repo", "github.com/owner/repo"),
        ("UNRECOGNIZED_SECRET", "<target>"),
        ("owner/repo?token=token-secret", "<target>"),
        ("https://[broken]?token=token-secret", "https://[broken]"),
        ("https://[?token=token-secret", "<target>"),
        ("https://example.com:invalid/foo.zip?token=token-secret", "<target>"),
        ("ftp://credential-user:credential-password@example.com/foo.zip", "<URL>")
    ])
    func errorsFormatTargetsWithoutChangingTheirValues(target: String, expected: String) throws {
        let missing = ChecksumOptionError.missingChecksum(target: target)
        let missingInstall = ChecksumOptionError.missingInstallChecksum(target: target)
        let changed = NestfileControllerError.checksumChanged(target: target, version: "1.0.0", expected: "old-checksum", actual: "new-checksum")

        #expect(missing.localizedDescription.hasPrefix("Missing checksum for \"\(expected)\" in the nestfile."))
        #expect(missingInstall.localizedDescription.hasPrefix("Missing checksum for \"\(expected)\"."))
        #expect(changed.localizedDescription.hasPrefix("Checksum changed for \"\(expected)\" at version 1.0.0"))
        #expect(missing.localizedDescription.contains("nest update-nestfile"))
        #expect(missingInstall.localizedDescription.contains("--checksum <value>"))
        #expect(changed.localizedDescription.contains("expected: old-checksum"))
        #expect(changed.localizedDescription.contains("actual:   new-checksum"))

        guard case .missingChecksum(let missingTarget) = missing,
              case .missingInstallChecksum(let installTarget) = missingInstall,
              case .checksumChanged(let changedTarget, _, _, _) = changed else {
            Issue.record("Unexpected checksum error")
            return
        }
        #expect(missingTarget == target)
        #expect(installTarget == target)
        #expect(changedTarget == target)
    }
}
