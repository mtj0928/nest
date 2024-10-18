import Foundation

public struct GitRepositoryClientBuilder {
    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func build(for url: GitURL) -> any GitRepositoryClient {
        // Only GitHub is supported now.
        GitHubRepositoryClient(httpClient: configuration.httpClient, logger: configuration.logger)
    }

    public func build(for url: URL) -> any GitRepositoryClient {
        build(for: .url(url))
    }
}
