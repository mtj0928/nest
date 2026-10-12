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

    @Test(arguments: [
        "https://url-user:url-password@example.com/tool.zip?signature=url-token#url-fragment",
        "https://example.com/tool.zip?custom=url-token"
    ])
    func notFoundErrorKeepsOriginalURLAndHidesItsSecrets(input: String) async throws {
        let url = try #require(URL(string: input))
        let client = MockHTTPClient(mockFileSystem: mockFileSystem)
        let downloader = NestFileDownloader(httpClient: client)

        do {
            _ = try await downloader.download(url: url)
            Issue.record("Expected a not found error")
        } catch let error as FileDownloaderError {
            #expect(error == .notFound(url: url))
            #expect(error.localizedDescription == "Not found: https://example.com/tool.zip")
        }
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
