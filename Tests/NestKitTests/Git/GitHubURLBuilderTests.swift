import Foundation
import Testing
@testable import NestKit

struct GitHubURLBuilderTests {
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
    func testReleaseURL(parameter: (urlString: String, tag: GitVersion, expect: String)) throws {
        let url = try #require(URL(string: parameter.urlString))
        let assetURL = try GitHubURLBuilder.assetURL(url, version: parameter.tag)
        #expect(assetURL == URL(string: parameter.expect))
    }
}
