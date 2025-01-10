import Foundation
import NestKit
import Yams

public struct Nestfile: Codable, Sendable {
    public var nestPath: String?
    public var targets: [Target]
    public var servers: ServerConfigs?

    public init(nestPath: String?, targets: [Target]) {
        self.nestPath = nestPath
        self.targets = targets
    }

    public enum Target: Codable, Equatable, Sendable {
        case repository(Repository)
        case deprecatedZIP(DeprecatedZIPURL)
        case zip(ZIPURL)

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let repository = try? container.decode(Repository.self) {
                self = .repository(repository)
            } else if let zipURL = try? container.decode(ZIPURL.self) {
                self = .zip(zipURL)
            } else if let zipURL = try? container.decode(DeprecatedZIPURL.self) {
                self = .deprecatedZIP(zipURL)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected repository or zip URL")
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .repository(let repository):
                try container.encode(repository)
            case .deprecatedZIP(let deprecatedZIPURL):
                try container.encode(deprecatedZIPURL)
            case .zip(let zipURL):
                try container.encode(zipURL)
            }
        }

        public var isDeprecatedZIP: Bool {
            switch self {
            case .deprecatedZIP: return true
            default: return false
            }
        }
    }

    public struct Repository: Codable, Equatable, Sendable {
        /// A reference to a repository.
        ///
        /// The acceptable formats are the followings
        /// - `{owner}/{name}`
        /// - HTTPS URL
        /// - SSH URL.
        public var reference: String
        public var version: String?

        /// Specify an asset file name of an artifact bundle.
        /// If the name is not specified, the tool fetch the name by GitHub API.
        public var assetName: String?
        public var checksum: String?

        public init(reference: String, version: String?, assetName: String?, checksum: String?) {
            self.reference = reference
            self.version = version
            self.assetName = assetName
            self.checksum = checksum
        }
    }

    public struct DeprecatedZIPURL: Codable, Equatable, Sendable {
        public var url: String

        public init(url: String) {
            self.url = url
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.url = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(url)
        }
    }

    public struct ZIPURL: Codable, Equatable, Sendable {
        public var zipURL: String
        public var checksum: String?

        public init(zipURL: String, checksum: String?) {
            self.zipURL = zipURL
            self.checksum = checksum
        }

        enum CodingKeys: String, CodingKey {
            case zipURL = "zipURL"
            case checksum
        }
    }

    public struct ServerConfigs: Codable, Sendable {
        public var github: [GitHubInfo]

        public struct GitHubInfo: Codable, Sendable {
            public var host: String
            public var tokenEnvironmentVariable: String
        }
    }
}

extension Nestfile {
    public func write(to path: String, fileSystem: some FileSystem) throws {
        let url = URL(fileURLWithPath: path)
        let data = try YAMLEncoder().encode(self)
        try fileSystem.write(data.data(using: .utf8)!, to: url)
    }

    public static func load(from path: String, fileSystem: some FileSystem) throws -> Nestfile {
        let url = URL(fileURLWithPath: path)
        let data = try fileSystem.data(at: url)
        return try YAMLDecoder().decode(Nestfile.self, from: data)
    }
}

extension Nestfile.ServerConfigs {
    public typealias GitHubHost = String
    public var githubServerTokenEnvironmentVariableNames: [GitHubHost: String] {
        github.reduce(into: [:]) { $0[$1.host] = $1.tokenEnvironmentVariable }
    }
}
