import Foundation
import HTTPTypes
import HTTPTypesFoundation
import ZIPFoundation

public protocol FileDownloader: Sendable {
    func download(url: URL, to destinationPath: URL) async throws
}

public struct NestFileDownloader: FileDownloader {
    let httpClient: any HTTPClient
    let fileStorage: any FileStorage

    public init(httpClient: some HTTPClient, fileStorage: some FileStorage) {
        self.httpClient = httpClient
        self.fileStorage = fileStorage
    }

    public func download(url: URL, to destinationPath: URL) async throws {
        let request = HTTPRequest(url: url)
        let (downloadedFilePath, response) = try await httpClient.download(for: request)
        if response.status == .notFound {
            throw FileDownloaderError.notFound(url: url)
        }

        if url.needsUnzip {
            fileStorage.unzipItem(at: downloadedFilePath, to: destinationPath)
        } else {
            try fileStorage.copyItem(at: downloadedFilePath, to: destinationPath)
        }
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
