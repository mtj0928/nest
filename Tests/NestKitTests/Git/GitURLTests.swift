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
            "example.com/owner/repo/foo",
            expect: GitURL.url(URL(string: "https://example.com/owner/repo/foo")!)
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
        let gitURL = try #require(GitURL.parse(from: parameter.argument))
        #expect(gitURL == parameter.expect)
    }

    @Test(arguments:["repo"])
    func parseGitURLOnFailureCase(argument: String) throws {
        let repository = GitURL.parse(from: argument)
        #expect(repository == nil)
    }

    @Test(arguments:[
        ("owner/repo", expect: "repo"),
        ("https://github.com/owner/repo", expect: "repo"),
        ("github.com/owner/repo", "repo"),
        ("git@github.com:owner/repo.git", expect: "repo")
    ])
    func repositoryName(parameter: (name: String, expect: String)) {
        let repository = GitURL.parse(from: parameter.name)
        #expect(repository?.repositoryName == parameter.expect)
    }
    
    @Test(arguments: [
        ("owner/repo", expect: "owner/repo"),
        ("https://github.com/owner/repo", expect: "owner/repo"),
        ("github.com/owner/repo", "owner/repo"),
        ("git@github.com:owner/repo.git", expect: "owner/repo")
    ])
    func referenceName(name: String, expected: String) {
        let repository = GitURL.parse(from: name)
        #expect(repository?.reference == expected)
    }

    @Test(arguments:[
        ("owner/repo", expect: "https://github.com/owner/repo"),
        ("https://github.com/owner/repo", expect: "https://github.com/owner/repo"),
        ("github.com/owner/repo", "https://github.com/owner/repo"),
        ("git@github.com:owner/repo.git", expect: "git@github.com:owner/repo.git")
    ])
    func stringURL(parameter: (name: String, expect: String)) {
        let repository = GitURL.parse(from: parameter.name)
        #expect(repository?.stringURL == parameter.expect)
    }
}
