import Foundation
import HTTPTypes
import HTTPTypesFoundation
import ZIPFoundation

public protocol FileDownloader: Sendable {
    func download(url: URL, to destinationPath: URL) async throws
}

public struct NestFileDownloader: FileDownloader {
    let httpClient: any HTTPClient
    let fileSystem: any FileSystem

    public init(httpClient: some HTTPClient, fileSystem: some FileSystem) {
        self.httpClient = httpClient
        self.fileSystem = fileSystem
    }

    public func download(url: URL, to destinationPath: URL) async throws {
        let request = HTTPRequest(url: url)
        let (downloadedFilePath, response) = try await httpClient.download(for: request)
        if response.status == .notFound {
            throw FileDownloaderError.notFound(url: url)
        }

        if url.needsUnzip {
            fileSystem.unzipItem(at: downloadedFilePath, to: destinationPath)
        } else {
            try fileSystem.copyItem(at: downloadedFilePath, to: destinationPath)
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
