import Foundation

public enum GitHubURLBuilder {
    /// Builds a download URL for an asset in a specified version in a specified repository.
    /// - Parameters:
    ///   - url: A URL to a repository.
    ///   - version: A specified version.
    ///   - fileName: A specified file name.
    /// - Returns: An HTTPS asset download URL.
    /// - Throws: ``InvalidURLError`` when the repository URL is invalid or an Enterprise URL is not HTTPS.
    public static func assetDownloadURL(_ url: URL, version: String, fileName: String) throws(InvalidURLError) -> URL {
        let repositoryURL = try validatedRepositoryURL(url)
        return repositoryURL.appending(components: "releases", "download", version, fileName)
    }

    static func assetURL(_ url: URL, version: GitVersion) throws(InvalidURLError) -> APIRequestTarget {
        let target = try repositoryTarget(from: url)

        let requestURL = switch version {
        case .latestRelease:
            target.baseURL.appending(components: "repos", target.owner, target.repository, "releases", "latest")
        case .tag(let string):
            target.baseURL.appending(components: "repos", target.owner, target.repository, "releases", "tags", string)
        }
        return APIRequestTarget(url: requestURL, registryHost: target.registryHost)
    }

    static func releasesAssetURL(_ url: URL) throws(InvalidURLError) -> APIRequestTarget {
        let target = try repositoryTarget(from: url)

        // Since the latest version is returned in descending order, pagination isn't supported.
        let requestURL = target.baseURL.appending(components: "repos", target.owner, target.repository, "releases")
        return APIRequestTarget(url: requestURL, registryHost: target.registryHost)
    }

    private static func repositoryTarget(from url: URL) throws(InvalidURLError) -> RepositoryTarget {
        guard url.pathComponents.count >= 3 else {
            throw InvalidURLError(url: url)
        }

        let owner = url.pathComponents[1]
        let repository = url.pathComponents[2]
        guard let hostName = url.host() else {
            throw InvalidURLError(url: url)
        }
        let registryHost = GitHubRegistryConfigs.Host(hostName)
        let baseURL = try baseAPIURL(from: url, registryHost: registryHost)

        return RepositoryTarget(baseURL: baseURL, registryHost: registryHost, owner: owner, repository: repository)
    }

    private static func baseAPIURL(
        from url: URL,
        registryHost: GitHubRegistryConfigs.Host
    ) throws(InvalidURLError) -> URL {
        switch registryHost {
        case .githubCom:
            return URL(string: "https://api.github.com/")!
        case .custom:
            guard url.scheme?.lowercased() == "https" else {
                throw InvalidURLError(url: url)
            }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.user = nil
            components?.password = nil
            components?.path = ""
            components?.query = nil
            components?.fragment = nil
            guard let baseURL = components?.url else {
                throw InvalidURLError(url: url)
            }
            return baseURL.appending(components: "api", "v3")
        }
    }

    private static func validatedRepositoryURL(_ url: URL) throws(InvalidURLError) -> URL {
        guard let hostName = url.host() else {
            throw InvalidURLError(url: url)
        }
        let registryHost = GitHubRegistryConfigs.Host(hostName)
        if case .custom = registryHost, url.scheme?.lowercased() != "https" {
            throw InvalidURLError(url: url)
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        components?.user = nil
        components?.password = nil
        components?.query = nil
        components?.fragment = nil
        guard let repositoryURL = components?.url else {
            throw InvalidURLError(url: url)
        }
        return repositoryURL
    }
}

extension GitHubURLBuilder {
    private struct RepositoryTarget {
        let baseURL: URL
        let registryHost: GitHubRegistryConfigs.Host
        let owner: String
        let repository: String
    }

    struct APIRequestTarget: Sendable {
        let url: URL
        let registryHost: GitHubRegistryConfigs.Host

        fileprivate init(url: URL, registryHost: GitHubRegistryConfigs.Host) {
            self.url = url
            self.registryHost = registryHost
        }
    }

    public struct InvalidURLError: LocalizedError, Sendable {
        /// The rejected repository URL.
        public var url: URL

        /// A description of the validation failure.
        public var errorDescription: String? {
            "Invalid or insecure GitHub repository URL: \(url.logDescription). GitHub Enterprise URLs must use HTTPS."
        }

        /// A description of why URL validation failed.
        public var failureReason: String? {
            errorDescription
        }
    }
}
