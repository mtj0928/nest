import Foundation
import Testing
@testable import NestKit

struct GitHubURLBuilderTests {
    @Test(arguments:[
        (
            urlString: "https://github.com/owner/repo",
            tag: "latest",
            expect: "https://api.github.com/repos/owner/repo/releases/latest"
        ),
        (
            urlString: "https://matsuji.net/owner/repo",
            tag: "latest",
            expect: "https://matsuji.net/api/v3/repos/owner/repo/releases/latest"
        ),
    ])
    func testReleaseURL(parameter: (urlString: String, tag: String, expect: String)) throws {
        let url = try #require(URL(string: parameter.urlString))
        let assetURL = try GitHubURLBuilder.assetURL(url, tag: parameter.tag)
        #expect(assetURL == URL(string: parameter.expect))
    }
}
