import Foundation
import HTTPTypes
import HTTPTypesFoundation
import ZIPFoundation

public protocol FileDownloader: Sendable {
    func download(url: URL, to destinationPath: URL) async throws
}

public struct NestFileDownloader: FileDownloader {
    let urlSession: URLSession
    let fileManager: FileManager

    public init(urlSession: URLSession, fileManager: FileManager) {
        self.urlSession = urlSession
        self.fileManager = fileManager
    }

    public func download(url: URL, to destinationPath: URL) async throws {
        let request = HTTPRequest(url: url)
        let (downloadedFilePath, response) = try await urlSession.download(for: request)
        if response.status == .notFound {
            throw FileDownloaderError.notFound(url: url)
        }

        if url.needsUnzip {
            try fileManager.unzipItem(at: downloadedFilePath, to: destinationPath)
        } else {
            try fileManager.copyItem(at: downloadedFilePath, to: destinationPath)
        }
    }
}

enum FileDownloaderError: LocalizedError {
    case notFound(url: URL)

    var errorDescription: String? {
        switch self {
        case .notFound(let url):
            "Not found: \(url.absoluteString)"
        }
    }
}
