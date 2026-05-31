import Testing
@testable import nest

struct ChecksumValidationPolicyArgumentTests {
    @Test(arguments: [
        ("skip", ChecksumValidationPolicyArgument.skip),
        ("warn", .warn),
        ("require", .require)
    ])
    func initialize(argument: String, expectedPolicyArgument: ChecksumValidationPolicyArgument) {
        #expect(ChecksumValidationPolicyArgument(argument: argument) == expectedPolicyArgument)
    }

    @Test
    func invalidArgument() {
        #expect(ChecksumValidationPolicyArgument(argument: "invalid") == nil)
    }
}
