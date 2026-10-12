import Foundation
import Testing
@testable import NestKit

struct GitHubURLBuilderTests {
    @Test(arguments: [
        "http://url-user:url-password@ghe.example.com/owner/repo?token=url-token#url-fragment",
        "https://url-user:url-password@ghe.example.com/owner?token=url-token#url-fragment"
    ])
    func rejectedURLsRemainAvailableWithoutLeakingThroughDiagnostics(input: String) throws {
        let url = try #require(URL(string: input))

        do {
            _ = try GitHubURLBuilder.assetURL(url, version: .latestRelease)
            Issue.record("Expected an invalid repository URL error")
        } catch {
            #expect(error.url == url)
            #expect(error.localizedDescription.contains(url.logDescription))
            #expect(error.failureReason == error.errorDescription)
            for secret in ["url-user", "url-password", "url-token", "url-fragment", "token="] {
                #expect(!error.localizedDescription.contains(secret))
            }
        }
    }

    @Test(arguments:[
        (
            urlString: "https://github.com/owner/repo",
            tag: GitVersion.latestRelease,
            expect: "https://api.github.com/repos/owner/repo/releases/latest"
        ),
        (
            urlString: "https://github.com/owner/repo",
            tag: .tag("1.2.3"),
            expect: "https://api.github.com/repos/owner/repo/releases/tags/1.2.3"
        ),
        (
            urlString: "https://matsuji.net/owner/repo",
            tag: .latestRelease,
            expect: "https://matsuji.net/api/v3/repos/owner/repo/releases/latest"
        ),
    ])
    func assetURL(parameter: (urlString: String, tag: GitVersion, expect: String)) throws {
        let url = try #require(URL(string: parameter.urlString))
        let requestTarget = try GitHubURLBuilder.assetURL(url, version: parameter.tag)
        #expect(requestTarget.url == URL(string: parameter.expect))
    }

    @Test(arguments: [
        (
            urlString: "https://github.com/owner/repo",
            expected: "https://api.github.com/repos/owner/repo/releases"
        ),
        (
            urlString: "https://matsuji.net/owner/repo",
            expected: "https://matsuji.net/api/v3/repos/owner/repo/releases"
        )
    ])
    func releaseAssetURL(urlString: String, expect: String) throws {
        let url = try #require(URL(string: urlString))
        let requestTarget = try GitHubURLBuilder.releasesAssetURL(url)
        #expect(requestTarget.url == URL(string: expect))
    }

    @Test
    func downloadURL() throws {
        let url = try #require(URL(string: "https://github.com/owner/repo"))
        let assetURL = try GitHubURLBuilder.assetDownloadURL(url, version: "0.1.0", fileName: "foo.txt")
        #expect(assetURL == URL(string: "https://github.com/owner/repo/releases/download/0.1.0/foo.txt"))
    }

    @Test(arguments: [
        "http://ghe.example.com/owner/repo",
        "HTTP://ghe.example.com/owner/repo"
    ])
    func rejectsInsecureEnterpriseRepositoryURLBeforeBuildingRequest(urlString: String) throws {
        let url = try #require(URL(string: urlString))

        #expect(throws: GitHubURLBuilder.InvalidURLError.self) {
            try GitHubURLBuilder.assetURL(url, version: .latestRelease)
        }
    }
}
