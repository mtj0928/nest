import Foundation
import Logging

public struct Configuration: Sendable {
    public var urlSession: URLSession
    public var fileManager: FileManager
    public var logger: Logger

    public init(
        urlSession: URLSession,
        fileManager: FileManager,
        logger: Logger
    ) {
        self.urlSession = urlSession
        self.fileManager = fileManager
        self.logger = logger
    }
}

extension FileManager: @unchecked Sendable {}
