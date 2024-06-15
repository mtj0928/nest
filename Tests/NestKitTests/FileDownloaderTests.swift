import Foundation
import Testing
@testable import NestKit

struct InstallTargetTests {
    @Test
    func testNeedsUnzipForZip() throws {
        let downloader = ZipFileDownloader(urlSession: .shared, fileManager: .default)
        let url = URL(string: "artifactBundle.zip")!
        #expect(downloader.needsUnzip(for: url))
    }
    
    @Test
    func testNeedsUnzipForNonArchivedFile() throws {
        let downloader = ZipFileDownloader(urlSession: .shared, fileManager: .default)
        let url = URL(string: "artifactBundle.ipa")!
        #expect(downloader.needsUnzip(for: url) == false)
    }
}
