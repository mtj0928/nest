@testable import NestKit
import Testing

struct ExcludedTargetTests {
    @Test(
        arguments: [
            (
                argument: "owner/repo",
                expected: ExcludedTarget(reference: "owner/repo", version: nil)
            ),
            (
                argument: "owner/repo@0.0.1",
                expected: ExcludedTarget(reference: "owner/repo", version: "0.0.1")
            ),
            (
                argument: "foo@owner/repo@0.0.1",
                expected: nil
            )
        ]
    )
    func parse(argument: String, expected: ExcludedTarget?) async throws {
        #expect(ExcludedTarget(argument: argument) == expected)
    }
}
