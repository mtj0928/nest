import Testing
@testable import nest

struct SubCommandOfRunCommandTests {
    @Test(arguments: [
        (["owner/repo"], "owner/repo", []),
        (["owner/repo", "--option"], "owner/repo", ["--option"]),
        (["owner/repo", "subcommand", "--option"], "owner/repo", ["subcommand", "--option"])
    ])
    func initialize(arguments: [String], expectedReference reference: String, expectedSubcommands subcommands: [String]?) throws {
        let executor = try SubCommandOfRunCommand(arguments: arguments)
        #expect(executor.repository.reference == reference)
        #expect(executor.arguments == subcommands)
    }
    
    @Test(arguments: [
        ([], SubCommandOfRunCommand.ParseError.emptyArguments),
        ([""], .invalidFormat),
        (["ownerrepo"], .invalidFormat)
    ])
    func failedInitialize(arguments: [String], expectedError error: SubCommandOfRunCommand.ParseError) throws {
        #expect(throws: error, performing: {
            try SubCommandOfRunCommand(arguments: arguments)
        })
    }
}
