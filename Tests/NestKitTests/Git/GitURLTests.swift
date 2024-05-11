import Foundation
import Testing
@testable import NestKit

struct GitURLTests {
    @Test(arguments:[
        (
            "owner/repo",
            expect: GitURL.url(URL(string: "https://github.com/owner/repo")!)
        ),
        (
            "https://github.com/owner/repo",
            expect: .url(URL(string: "https://github.com/owner/repo")!)
        ),
        (
            "github.com/owner/repo",
            expect: .url(URL(string: "https://github.com/owner/repo")!)
        ),
        (
            "git@github.com:owner/repo.git",
            expect: .ssh(SSHURL(user: "git", host: "github.com", path: "owner/repo.git"))
        )
    ])
    func parseGitURLOnSuccessCase(parameter: (argument: String, expect: GitURL)) throws {
        let gitURL = try #require(GitURL.parse(string: parameter.argument))
        #expect(gitURL == parameter.expect)
    }

    @Test(arguments:["repo"])
    func parseGitURLOnFailureCase(argument: String) throws {
        let repository = GitURL.parse(string: argument)
        #expect(repository == nil)
    }
}
