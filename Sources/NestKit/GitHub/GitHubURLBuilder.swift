import Foundation

public enum GitHubURLBuilder {
    /// Builds a download url for an asset in a specified version in a specified repository.
    /// - Parameters:
    ///   - url: A URL to a repository
    ///   - version: A specified version
    ///   - fileName: A specified file name.
    public static func assetDownloadURL(_ url: URL, version: String, fileName: String) -> URL {
        url.appending(components: "releases", "download", version, fileName)
    }

    static func assetURL(_ url: URL, version: GitVersion) throws -> URL {
        guard url.pathComponents.count >= 3 else {
            throw InvalidURLError(url: url)
        }
        let owner = url.pathComponents[1]
        let repository = url.pathComponents[2]

        guard let baseURL = baseAPIURL(from: url) else {
            throw InvalidURLError(url: url)
        }

        switch version {
        case .latestRelease:
            return baseURL.appending(components: "repos", owner, repository, "releases", "latest")
        case .tag(let string):
            return baseURL.appending(components: "repos", owner, repository, "releases", "tags", string)
        }
    }

    private static func baseAPIURL(from url: URL) -> URL? {
        if url.host() == "github.com" {
            return URL(string: "https://api.github.com/")
        }
        else {
            // GitHub Enterprise
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.path = ""
            components?.query = nil
            components?.fragment = nil
            return components?.url?.appending(components: "api", "v3")
        }
    }
}

extension GitHubURLBuilder {
    public struct InvalidURLError: LocalizedError {
        public var url: URL
        public var failureReason: String? {
            "Invalid url: \(url)"
        }
    }
}
