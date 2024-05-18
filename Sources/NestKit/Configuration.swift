import Foundation
import Logging

public struct Configuration: Sendable {
    public var urlSession: URLSession
    public var fileManager: FileManager
    public var zipFileDownloader: ZipFileDownloader
    public var workingDirectory: URL
    public var nestDirectory: NestDirectory
    public var nestFileManager: NestFileManager
    public var logger: Logger

    public init(
        urlSession: URLSession,
        fileManager: FileManager,
        zipFileDownloader: ZipFileDownloader,
        workingDirectory: URL,
        nestDirectory: NestDirectory,
        nestFileManager: NestFileManager,
        logger: Logger
    ) {
        self.urlSession = urlSession
        self.fileManager = fileManager
        self.zipFileDownloader = zipFileDownloader
        self.workingDirectory = workingDirectory
        self.nestDirectory = nestDirectory
        self.nestFileManager = nestFileManager
        self.logger = logger
    }
}

extension FileManager: @unchecked Sendable {}
