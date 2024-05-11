import Foundation

public enum GitRepositoryClientBuilder {
    public static func build(url: GitURL, configuration: Configuration) -> any GitRepositoryClient {
        // Only github is supported now.
        GitHubRepositoryClient(urlSession: configuration.urlSession)
    }
}
