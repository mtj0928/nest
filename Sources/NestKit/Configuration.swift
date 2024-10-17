import Foundation
import Logging

public struct Configuration: Sendable {
    public var urlSession: URLSession
    public var fileManager: FileManager
    public var fileDownloader: any FileDownloader
    public var workingDirectory: URL
    public var nestDirectory: NestDirectory
    public var artifactBundleManager: ArtifactBundleManager
    public var logger: Logger

    public init(
        urlSession: URLSession,
        fileManager: FileManager,
        fileDownloader: some FileDownloader,
        workingDirectory: URL,
        nestDirectory: NestDirectory,
        artifactBundleManager: ArtifactBundleManager,
        logger: Logger
    ) {
        self.urlSession = urlSession
        self.fileManager = fileManager
        self.fileDownloader = fileDownloader
        self.workingDirectory = workingDirectory
        self.nestDirectory = nestDirectory
        self.artifactBundleManager = artifactBundleManager
        self.logger = logger
    }
}

extension FileManager: @unchecked Swift.Sendable {}
