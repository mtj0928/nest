import Foundation
import Logging

public struct Configuration: Sendable {
    public var httpClient: any HTTPClient
    public var fileSystem: any FileSystem
    public var fileDownloader: any FileDownloader
    public var workingDirectory: URL
    public var assetRegistryClientBuilder: AssetRegistryClientBuilder
    public var nestDirectory: NestDirectory
    public var artifactBundleZIPCacheOption: ArtifactBundleZIPCacheOption
    public var artifactBundleManager: ArtifactBundleManager
    /// Registry token environment variables that must not be inherited by executed packages.
    public var registryTokenEnvironmentVariableNames: Set<String>
    public var logger: Logger

    public init(
        httpClient: some HTTPClient,
        fileSystem: any FileSystem,
        fileDownloader: some FileDownloader,
        workingDirectory: URL,
        assetRegistryClientBuilder: AssetRegistryClientBuilder,
        nestDirectory: NestDirectory,
        artifactBundleZIPCacheOption: ArtifactBundleZIPCacheOption,
        artifactBundleManager: ArtifactBundleManager,
        registryTokenEnvironmentVariableNames: Set<String> = [],
        logger: Logger
    ) {
        self.httpClient = httpClient
        self.fileSystem = fileSystem
        self.fileDownloader = fileDownloader
        self.workingDirectory = workingDirectory
        self.assetRegistryClientBuilder = assetRegistryClientBuilder
        self.nestDirectory = nestDirectory
        self.artifactBundleZIPCacheOption = artifactBundleZIPCacheOption
        self.artifactBundleManager = artifactBundleManager
        self.registryTokenEnvironmentVariableNames = registryTokenEnvironmentVariableNames
        self.logger = logger
    }
}

extension FileManager: @unchecked Swift.Sendable {}
