import Foundation

public enum GitURL: Sendable, Hashable {
    case url(URL)
    case ssh(SSHURL)

    public static func parse(string: String) -> GitURL? {
        if let sshURL = SSHURL(string: string) {
            return .ssh(sshURL)
        }

        guard let url = URL(string: string) else { return nil }

        // github.com/xxx/yyy or https://github.com/xxx/yyy
        if url.host() != nil {
            let fileNameWithoutPathExtension = url.fileNameWithoutPathExtension
            return .url(url.deletingLastPathComponent().appending(path: fileNameWithoutPathExtension))
        }

        // xxx/yyy
        if url.pathComponents.count == 2,
           url.scheme == nil,
           url.host() == nil,
           let url = URL(string: "https://github.com/\(string)") {
            return .url(url)
        }

        if url.pathComponents.count >= 2,
           let url = URL(string: "https://\(string)") {
            return .url(url)
        }

        return nil
    }
}

public struct SSHURL: Sendable, Hashable {
    public let user: String
    public let host: String
    public let path: String

    public init(user: String, host: String, path: String) {
        self.user = user
        self.host = host
        self.path = path
    }

    public init?(string: String) {
        // git@github.com/xxx/yyy
        let regex = /^(?<user>[a-zA-Z0-9_]+)@(?<host>[a-zA-Z0-9.-]+):(?<path>[a-zA-Z0-9_.\/-]+)(\.git)?$/

        guard let match = try? regex.wholeMatch(in: string) else { return nil }

        let user = String(match.output.user)
        let host = String(match.output.host)
        let path = String(match.output.path)

        self.init(user: user, host: host, path: path)
    }
}
