@testable import NestKit
import Testing

struct ExcludedVersionTests {
    @Test(
        arguments: [
            (
                argument: "owner/repo",
                expected: ExcludedVersion(reference: "owner/repo", version: nil)
            ),
            (
                argument: "owner/repo@0.0.1",
                expected: ExcludedVersion(reference: "owner/repo", version: "0.0.1")
            )
        ]
    )
    func parse(argument: String, expected: ExcludedVersion) async throws {
        #expect(ExcludedVersion(argument: argument) == expected)
    }
}
