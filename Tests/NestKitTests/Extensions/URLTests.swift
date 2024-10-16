import Foundation
import Testing
@testable import NestKit

struct URLTests {
    @Test
    func testNeedsUnzipForZip() throws {
        let url = #require(URL(string: "artifactBundle.zip"))
        #expect(url.needsUnzip)
    }

    @Test
    func testNeedsUnzipForNonArchivedFile() throws {
        let url = #require(URL(string: "artifactBundle.ipa"))
        #expect(!url.needsUnzip)
    }
}
