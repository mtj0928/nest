import Foundation

public struct ExecutableBinary {
    public var commandName: String
    public var binaryPath: URL
    public var source: ExecutorBinarySource
    public var version: String
    public var manufacturer: ExecutableManufacturer

    public init(commandName: String, binaryPath: URL, source: ExecutorBinarySource, version: String, manufacturer: ExecutableManufacturer) {
        self.commandName = commandName
        self.binaryPath = binaryPath
        self.source = source
        self.version = version
        self.manufacturer = manufacturer
    }
}

public enum ExecutorBinarySource: Codable, CustomStringConvertible {
    case git(GitURL)
    case url(URL)

    enum CodingKeys: CodingKey {
        case git
        case url
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var allKeys = ArraySlice(container.allKeys)
        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
            throw DecodingError.typeMismatch(ExecutorBinarySource.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
        }
        switch onlyKey {
        case .git:
            let gitURL = try container.decode(GitURL.self, forKey: .git)
            self = .git(gitURL)
        case .url:
            let url = try container.decode(URL.self, forKey: .url)
            self = .url(url)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .git(let gitURL):
            try container.encode(gitURL, forKey: .git)
        case .url(let url):
            try container.encode(url, forKey: .url)
        }
    }

    var identifier: String {
        switch self {
        case .git(let gitURL): 
            return gitURL.sourceIdentifier
        case .url(let url):
            let path = url.path().replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ".\(url.pathExtension)", with: "")
            return [url.host(), path]
                .compactMap { $0 }
                .joined()
        }
    }

    public var description: String {
        switch self {
        case .git(let gitURL): gitURL.stringURL
        case .url(let url): url.absoluteString
        }
    }
}

public enum ExecutableManufacturer {
    case artifactBundle(fileName: String)
    case localBuild
}
