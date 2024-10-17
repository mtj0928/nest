import Foundation
import Testing
@testable import NestKit

struct URLTests {
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
