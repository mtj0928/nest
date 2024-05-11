import Foundation

enum GitHubURLBuilder {
    static func assetURL(_ url: URL, tag: String) throws -> URL {
        guard url.pathComponents.count >= 3 else {
            throw InvalidURLError(url: url)
        }
        let owner = url.pathComponents[1]
        let repository = url.pathComponents[2]

        guard let baseURL = baseAPIURL(from: url) else {
            throw InvalidURLError(url: url)
        }
        return baseURL.appending(components: "repos", owner, repository, "releases", tag)
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
        var failureReason: String? {
            "Invalid url: \(url)"
        }
    }
}
