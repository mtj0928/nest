import Foundation
import Logging

public struct GitRepositoryClientBuilder: Sendable {
    private let httpClient: any HTTPClient
    private let authToken: String?
    private let logger: Logger

    public init(httpClient: some HTTPClient, authToken: String?, logger: Logger) {
        self.httpClient = httpClient
        self.authToken = authToken
        self.logger = logger
    }

    public func build(for url: GitURL) -> any GitRepositoryClient {
        // Only GitHub is supported now.
        GitHubRepositoryClient(httpClient: httpClient, authToken: authToken, logger: logger)
    }

    public func build(for url: URL) -> any GitRepositoryClient {
        build(for: .url(url))
    }
}
