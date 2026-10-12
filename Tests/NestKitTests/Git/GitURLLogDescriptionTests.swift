import Foundation
import NestKit
import Testing

struct GitURLLogDescriptionTests {
    @Test(arguments: [
        "https://user:password@example.com/owner/repo.git?token=secret#private",
        "https://example.com/owner/repo.git?custom=secret"
    ])
    func removesHTTPSecretsWithoutChangingTheRepositoryURL(input: String) throws {
        let url = try #require(URL(string: input))
        let gitURL = GitURL.url(url)

        #expect(gitURL.logDescription == "https://example.com/owner/repo.git")
        #expect(gitURL.stringURL == input)
    }

    @Test
    func omitsSSHUserWithoutChangingTheRepositoryReference() throws {
        let input = "deployment_user@ghe.example.com:owner/repo.git"
        let gitURL = try #require(GitURL.parse(from: input))

        #expect(gitURL.logDescription == "ghe.example.com:owner/repo.git")
        #expect(gitURL.stringURL == input)
    }
}
