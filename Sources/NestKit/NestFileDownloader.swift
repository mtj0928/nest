import Foundation
import Logging
import HTTPTypes
import HTTPTypesFoundation
import ZIPFoundation

public protocol FileDownloader: Sendable {
    func download(url: URL, checksum: String?, to destinationPath: URL) async throws
}

public struct NestFileDownloader: FileDownloader {
    let httpClient: any HTTPClient
    let fileSystem: any FileSystem
    let checksumCalculator: any ChecksumCalculator
    let logger: Logger

    public init(
        httpClient: some HTTPClient,
        fileSystem: some FileSystem,
        checksumCalculator: some ChecksumCalculator,
        logger: Logger
    ) {
        self.httpClient = httpClient
        self.fileSystem = fileSystem
        self.checksumCalculator = checksumCalculator
        self.logger = logger
    }

    public func download(url: URL, checksum: String?, to destinationPath: URL) async throws {
        let request = HTTPRequest(url: url)
        let (downloadedFilePath, response) = try await httpClient.download(for: request)
        if response.status == .notFound {
            throw FileDownloaderError.notFound(url: url)
        }

        if url.needsUnzip {
            let downloadedZipFilePath = fileSystem.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try fileSystem.removeItemIfExists(at: downloadedZipFilePath)
            try fileSystem.copyItem(at: downloadedFilePath, to: downloadedZipFilePath)
            if let checksum {
                let calculatedChecksum = try await checksumCalculator.calculate(downloadedZipFilePath.path())
                if checksum != calculatedChecksum {
                    logger.warning(
                        """
                        ⚠️ The checksum of the downloaded file does not match the expected checksum.
                        expected: \(checksum)
                        actual:   \(calculatedChecksum)
                        """,
                        metadata: .color(.yellow)
                    )
                }
            }
            try fileSystem.unzip(at: downloadedFilePath, to: destinationPath)
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
