import Testing
@testable import nest

struct RunCommandArgumentTests {
    @Test(arguments: [
        (["owner/repo"], "owner/repo", []),
        (["owner/repo", "--option"], "owner/repo", ["--option"]),
        (["owner/repo", "subcommand", "--option"], "owner/repo", ["subcommand", "--option"])
    ])
    func initialize(arguments: [String], expectedReference reference: String, expectedSubcommands subcommands: [String]?) throws {
        let executor = try RunCommandArgument(arguments: arguments)
        #expect(executor.gitURL.reference == reference)
        #expect(executor.subcommands == subcommands)
    }
    
    @Test(arguments: [
        ([], RunCommandArgument.ParseError.emptyArguments),
        ([""], .invalidFormat),
        (["ownerrepo"], .invalidFormat)
    ])
    func failedInitialize(arguments: [String], expectedError error: RunCommandArgument.ParseError) throws {
        #expect(throws: error, performing: {
            try RunCommandArgument(arguments: arguments)
        })
    }
}
