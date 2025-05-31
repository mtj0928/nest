import Testing
import NestKit

struct GitHubRepositoryNameTests {

    @Test(arguments: [
        "foo/bar",
        "https://github.com/foo/bar",
        "https://github.com/foo/bar.git",
        "https://github.com/foo/bar/tree/main",
        "git@github.com:foo/bar.git"
    ])
    func parseString(_ string: String) async throws {
        let repositoryName = try #require(GitHubRepositoryName.parse(from: string))
        #expect(repositoryName == GitHubRepositoryName(owner: "foo", name: "bar"))
    }

    @Test(arguments: [
        "https://example.com/foo/bar",
        "https://exanple.com/foo/bar.git",
        "https://example.com/foo/bar/tree/main",
        "git@example.com:foo/bar.git"
    ])
    func parseFail(_ string: String) async throws {
        let repositoryName = GitHubRepositoryName.parse(from: string)
        #expect(repositoryName == nil)
    }
}
