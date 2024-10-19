import Foundation
import Testing
import NestTestHelpers
@testable import NestKit

struct NestFileDownloaderTests {
    let mockFileSystem = MockFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/User"),
        temporaryDirectory: URL(filePath: "/tmp")
    )

    init () {
        mockFileSystem.item = [
            "/": [
                "User": [:],
                "tmp": [:]
            ]
        ]
    }

    @Test
    func download() async throws {
        let httpClient = MockHTTPClient(mockFileSystem: mockFileSystem)
        let binary = try #require("foo".data(using: .utf8))
        let url = try #require(URL(string: "https://example.com/artifactbundle"))
        httpClient.dummyData[url] = binary
        let nestFileDownloader = NestFileDownloader(httpClient: httpClient)
        let downloadedURL = try await nestFileDownloader.download(url: url)
        try #expect(mockFileSystem.data(at: downloadedURL) == binary)
    }

    @Test
    func downloadButNotFound() async throws {
        let httpClient = MockHTTPClient(mockFileSystem: mockFileSystem)
        let url = try #require(URL(string: "https://example.com/artifactbundle"))
        let nestFileDownloader = NestFileDownloader(httpClient: httpClient)
        await #expect(throws: FileDownloaderError.notFound(url: url)) {
            try await nestFileDownloader.download(url: url)
        }
    }
}
