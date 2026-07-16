import Testing
@testable import nest

struct MissingChecksumPolicyArgumentTests {
    @Test(arguments: [
        ("skip", MissingChecksumPolicyArgument.skip),
        ("warn", .warn),
        ("require", .require)
    ])
    func initialize(argument: String, expectedPolicyArgument: MissingChecksumPolicyArgument) {
        #expect(MissingChecksumPolicyArgument(argument: argument) == expectedPolicyArgument)
    }

    @Test
    func invalidArgument() {
        #expect(MissingChecksumPolicyArgument(argument: "invalid") == nil)
    }
}
