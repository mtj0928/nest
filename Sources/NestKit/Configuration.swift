import Foundation
import Logging

public struct Configuration: Sendable {
    public var urlSession: URLSession
    public var fileStorage: any FileStorage
    public var fileDownloader: any FileDownloader
    public var workingDirectory: URL
    public var nestDirectory: NestDirectory
    public var artifactBundleManager: ArtifactBundleManager
    public var logger: Logger

    public init(
        urlSession: URLSession,
        fileStorage: any FileStorage,
        fileDownloader: some FileDownloader,
        workingDirectory: URL,
        nestDirectory: NestDirectory,
        artifactBundleManager: ArtifactBundleManager,
        logger: Logger
    ) {
        self.urlSession = urlSession
        self.fileStorage = fileStorage
        self.fileDownloader = fileDownloader
        self.workingDirectory = workingDirectory
        self.nestDirectory = nestDirectory
        self.artifactBundleManager = artifactBundleManager
        self.logger = logger
    }
}

extension FileManager: @unchecked Swift.Sendable {}
