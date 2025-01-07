import Foundation
import Logging

public struct Configuration: Sendable {
    public var httpClient: any HTTPClient
    public var fileSystem: any FileSystem
    public var fileDownloader: any FileDownloader
    public var workingDirectory: URL
    public var gitRepositoryClientBuilder: GitRepositoryClientBuilder
    public var nestDirectory: NestDirectory
    public var artifactBundleManager: ArtifactBundleManager
    public var logger: Logger

    public init(
        httpClient: some HTTPClient,
        fileSystem: any FileSystem,
        fileDownloader: some FileDownloader,
        workingDirectory: URL,
        gitRepositoryClientBuilder: GitRepositoryClientBuilder,
        nestDirectory: NestDirectory,
        artifactBundleManager: ArtifactBundleManager,
        logger: Logger
    ) {
        self.httpClient = httpClient
        self.fileSystem = fileSystem
        self.fileDownloader = fileDownloader
        self.workingDirectory = workingDirectory
        self.gitRepositoryClientBuilder = gitRepositoryClientBuilder
        self.nestDirectory = nestDirectory
        self.artifactBundleManager = artifactBundleManager
        self.logger = logger
    }
}

extension FileManager: @unchecked Swift.Sendable {}
