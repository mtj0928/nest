import Foundation
import Testing
@testable import NestKit

struct URLTests {
    @Test(arguments: [
        (URL(string: "https://github.com/owner/repo")!, "owner/repo"),
        (URL(string: "https://github.com/owner/repo.git")!, "owner/repo"),
        (URL(string: "https://github.com/owner/repo/releases/download/0.0.1/foo.artifactbundle.zip")!, "owner/repo"),
        (URL(string: "https://foo.com/bar/owner/repo")!, "bar/owner"),
        (URL(string: "https://foo.com/bar")!, nil)
    ])
    func testReference(url: URL, expected: String?) throws {
        #expect(url.reference == expected)
    }
    
    @Test
    func testNeedsUnzipForZip() throws {
        let url = try #require(URL(string: "artifactBundle.zip"))
        #expect(url.needsUnzip)
    }

    @Test
    func testNeedsUnzipForNonArchivedFile() throws {
        let url = try #require(URL(string: "artifactBundle.ipa"))
        #expect(!url.needsUnzip)
    }
}
