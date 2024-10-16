import Foundation
import ZIPFoundation

public struct ZipFileDownloader: Sendable {
    let urlSession: URLSession
    let fileManager: FileManager

    public init(urlSession: URLSession, fileManager: FileManager) {
        self.urlSession = urlSession
        self.fileManager = fileManager
    }

    public func download(url: URL, to destinationPath: URL) async throws {
        let (downloadedFilePath, response) = try await urlSession.download(from: url)
        if (response as? HTTPURLResponse)?.statusCode == 404 {
            throw ZipFileDownloaderError.notFound(url: url)
        }

        if url.needsUnzip {
            try fileManager.unzipItem(at: downloadedFilePath, to: destinationPath)
        } else {
            try fileManager.copyItem(at: downloadedFilePath, to: destinationPath)
        }
    }
}

enum ZipFileDownloaderError: LocalizedError {
    case notFound(url: URL)

    var errorDescription: String? {
        switch self {
        case .notFound(let url):
            "Not found: \(url.absoluteString)"
        }
    }
}
