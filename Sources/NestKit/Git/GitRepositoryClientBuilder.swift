import Foundation
import Logging

public struct GitRepositoryClientBuilder: Sendable {
    private let httpClient: any HTTPClient
    private let serverConfigs: GitHubServerConfigs?
    private let logger: Logger

    public init(httpClient: some HTTPClient, serverConfigs: GitHubServerConfigs?, logger: Logger) {
        self.httpClient = httpClient
        self.serverConfigs = serverConfigs
        self.logger = logger
    }

    public func build(for url: GitURL) -> any GitRepositoryClient {
        // Only GitHub is supported now.
        GitHubRepositoryClient(httpClient: httpClient, serverConfigs: serverConfigs, logger: logger)
    }

    public func build(for url: URL) -> any GitRepositoryClient {
        build(for: .url(url))
    }
}
