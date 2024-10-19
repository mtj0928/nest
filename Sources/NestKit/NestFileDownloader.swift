import Foundation
import Logging
import HTTPTypes
import HTTPTypesFoundation
import ZIPFoundation

public protocol FileDownloader: Sendable {
    func download(url: URL) async throws -> URL
}

public struct NestFileDownloader: FileDownloader {
    let httpClient: any HTTPClient

    public init(httpClient: some HTTPClient) {
        self.httpClient = httpClient
    }

    public func download(url: URL) async throws -> URL {
        let request = HTTPRequest(url: url)
        let (downloadedFilePath, response) = try await httpClient.download(for: request)
        if response.status == .notFound {
            throw FileDownloaderError.notFound(url: url)
        }
        return downloadedFilePath
    }
}

enum FileDownloaderError: LocalizedError, Equatable {
    case notFound(url: URL)

    var errorDescription: String? {
        switch self {
        case .notFound(let url):
            "Not found: \(url.absoluteString)"
        }
    }
}
