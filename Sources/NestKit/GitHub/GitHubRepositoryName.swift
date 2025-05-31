import Foundation

public struct GitHubRepositoryName: Sendable, Hashable {
    public var owner: String
    public var name: String

    public init?(owner: String, name: String) {
        guard Self.validate(owner), Self.validate(name) else { return nil }
        self.owner = owner
        self.name = name
    }

    public static func parse(from string: String) -> Self? {
        if let gitURL = GitURL.parse(string: string),
           let self = parse(from: gitURL) {
            return self
        }

        let components = string.split(separator: "/").map { String($0) }
        if components.count == 2 {
            return GitHubRepositoryName(owner: components[0], name: components[1].removingGitExtension())
        }
        return nil
    }

    public static func parse(from gitURL: GitURL) -> Self? {
        switch gitURL {
        case let .url(url): parse(from: url)
        case let .ssh(sshURL): parse(from: sshURL)
        }
    }

    public static func parse(from url: URL) -> Self? {
        guard url.host() == githubHost else { return nil }
        let components = url.pathComponents.compactMap { String($0) }

        // http://github.com/owner/name/main/...
        guard 2 <= components.count else {
            return nil
        }
        return GitHubRepositoryName(owner: components[1], name: components[2].removingGitExtension())
    }

    public static func parse(from sshURL: SSHURL) -> Self? {
        guard sshURL.host == githubHost else {
            return nil
        }
        
        let string = sshURL.path.removingGitExtension()
        return parse(from: string)
    }
}

extension GitHubRepositoryName {
    private static var githubHost: String { "github.com" }

    private static func validate(_ input: String) -> Bool {
        let invalidCharacters: [Character] = ["@", ":", "/"]
        return !input.contains { invalidCharacters.contains($0) }
    }
}

extension String {
    fileprivate func removingGitExtension() -> String {
        replacingOccurrences(of: ".git", with: "")
    }
}
