import Testing
import NestCLI

struct RunCommandExecutorTests {
    @Test(arguments: [
        (["owner/repo"], "owner/repo", []),
        (["owner/repo", "--option"], "owner/repo", ["--option"]),
        (["owner/repo", "subcommand", "--option"], "owner/repo", ["subcommand", "--option"])
    ])
    func initialize(arguments: [String], expectedReference reference: String, expectedSubcommands subcommands: [String]?) throws {
        let executor = try RunCommandExecutor(arguments: arguments)
        #expect(executor.reference == reference)
        #expect(executor.subcommands == subcommands)
    }
    
    @Test(arguments: [
        ([], RunCommandExecutor.ParseError.emptyArguments),
        ([""], RunCommandExecutor.ParseError.invalidFormat),
        (["ownerrepo"], RunCommandExecutor.ParseError.invalidFormat)
    ])
    func failedInitialize(arguments: [String], expectedError error: RunCommandExecutor.ParseError) throws {
        #expect(throws: error, performing: {
            try RunCommandExecutor(arguments: arguments)
        })
    }
}
