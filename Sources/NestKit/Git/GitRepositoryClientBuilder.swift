import Foundation

public enum GitRepositoryClientBuilder {
    public static func build(url: GitURL, configuration: Configuration) -> any GitRepositoryClient {
        // Only GitHub is supported now.
        GitHubRepositoryClient(urlSession: configuration.urlSession, logger: configuration.logger)
    }
}
