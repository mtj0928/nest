import Foundation
import ZIPFoundation
import UniformTypeIdentifiers

public struct ZipFileDownloader: Sendable {
    let urlSession: URLSession
    let fileManager: FileManager

    public init(urlSession: URLSession, fileManager: FileManager) {
        self.urlSession = urlSession
        self.fileManager = fileManager
    }

    public func download(url: URL, to destinationPath: URL) async throws {
        let (downloadedFilePath, _) = try await urlSession.download(from: url)
        if needsUnzip(for: url) {
            try fileManager.unzipItem(at: downloadedFilePath, to: destinationPath)
        } else {
            try fileManager.copyItem(at: downloadedFilePath, to: destinationPath)
        }
    }
    
    func needsUnzip(for url: URL) -> Bool {
        let utType = UTType(filenameExtension: url.pathExtension)
        return utType?.conforms(to: .zip) ?? false
    }
}
