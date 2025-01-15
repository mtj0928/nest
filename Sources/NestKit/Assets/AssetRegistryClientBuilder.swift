import Foundation
import Logging

public struct AssetRegistryClientBuilder: Sendable {
    private let httpClient: any HTTPClient
    private let serverConfigs: GitHubServerConfigs?
    private let logger: Logger

    public init(httpClient: some HTTPClient, serverConfigs: GitHubServerConfigs?, logger: Logger) {
        self.httpClient = httpClient
        self.serverConfigs = serverConfigs
        self.logger = logger
    }

    /// Build AssetRegistryClient based on the given git url.
    ///
    /// > Note: This function currently supports only GitHub.
    public func build(for url: GitURL) -> any AssetRegistryClient {
        // Only GitHub is supported now.
        GitHubAssetRegistryClient(httpClient: httpClient, serverConfigs: serverConfigs, logger: logger)
    }

    /// Build AssetRegistryClient based on the given url.
    ///
    /// > Note: This function currently supports only GitHub.
    public func build(for url: URL) -> any AssetRegistryClient {
        build(for: .url(url))
    }
}
