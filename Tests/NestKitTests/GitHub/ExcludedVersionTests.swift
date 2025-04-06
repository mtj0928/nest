@testable import NestKit
import Testing

struct ExcludedVersionTests {
    @Test(
        arguments: [
            (
                argument: "owner/repo",
                expected: ExcludedVersion(reference: "owner/repo", target: nil)
            ),
            (
                argument: "owner/repo@0.0.1",
                expected: ExcludedVersion(reference: "owner/repo", target: "0.0.1")
            ),
            (
                argument: "foo@owner/repo@0.0.1",
                expected: nil
            )
        ]
    )
    func parse(argument: String, expected: ExcludedVersion?) async throws {
        #expect(ExcludedVersion(argument: argument) == expected)
    }
}
