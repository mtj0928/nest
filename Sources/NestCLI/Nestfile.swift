import Foundation
import NestKit
import Yams

public struct Nestfile: Codable {
    public let nestPath: String?
    public let targets: [Target]

    public init(nestPath: String?, targets: [Target]) {
        self.nestPath = nestPath
        self.targets = targets
    }

    public enum Target: Codable {
        case repository(Repository)
        case zip(ZIPURL)

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let repository = try? container.decode(Repository.self) {
                self = .repository(repository)
            } else if let zipURL = try? container.decode(ZIPURL.self) {
                self = .zip(zipURL)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected repository or zip URL")
            }
        }
    }

    public struct Repository: Codable {
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

        public init(reference: String, version: String?, assetName: String?) {
            self.reference = reference
            self.version = version
            self.assetName = assetName
        }
    }

    public struct ZIPURL: Codable {
        public var url: String

        public init (url: String) {
            self.url = url
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.url = try container.decode(String.self)
        }
    }
}

extension Nestfile {
    public static func load(from path: String, fileStorage: some FileStorage) throws -> Nestfile {
        let url = URL(fileURLWithPath: path)
        let data = try fileStorage.data(at: url)
        return try YAMLDecoder().decode(Nestfile.self, from: data)
    }
}
