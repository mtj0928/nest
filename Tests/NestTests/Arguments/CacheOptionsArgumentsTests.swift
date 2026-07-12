import Testing
@testable import nest

struct CacheOptionsArgumentsTests {
    @Test
    func installCommandAcceptsUserScopeCacheOption() throws {
        let command = try InstallCommand.parse(["owner/repo", "--enable-user-scope-cache"])

        #expect(command.cacheOptions.enableUserScopeCache)
    }

    @Test
    func bootstrapCommandAcceptsUserScopeCacheOption() throws {
        let command = try BootstrapCommand.parse(["nestfile.yaml", "--enable-user-scope-cache"])

        #expect(command.cacheOptions.enableUserScopeCache)
    }

    @Test
    func runCommandAcceptsUserScopeCacheOption() throws {
        let command = try RunCommand.parse(["--enable-user-scope-cache", "owner/repo"])

        #expect(command.cacheOptions.enableUserScopeCache)
        #expect(command.arguments == ["owner/repo"])
    }
}
