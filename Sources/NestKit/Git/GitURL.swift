import Foundation

public enum GitURL: Sendable, Hashable, Codable {
    case url(URL)
    case ssh(SSHURL)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = Self.parse(string: string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Invalid format"))
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringURL)
    }

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

    public var repositoryName: String {
        switch self {
        case .url(let url): url.fileNameWithoutPathExtension
        case .ssh(let sshURL):
            String(sshURL.path.split(separator: "/").last ?? "")
                .replacingOccurrences(of: ".git", with: "")
        }
    }
    
    /// `owner/repo` format
    public var referenceName: String? {
        switch self {
        case let .url(url):
            return url.reference
        case let .ssh(sshURL):
            return sshURL.path.split(separator: ":").last?.replacingOccurrences(of: ".git", with: "")
        }
    }

    public var stringURL: String {
        switch self {
        case .url(let url): url.absoluteString
        case .ssh(let sshURL): sshURL.stringURL
        }
    }
}

public struct SSHURL: Sendable, Hashable, Codable {
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

    var stringURL: String {
        "\(user)@\(host):\(path)"
    }
}
