import Foundation

public struct ArtifactBundleRootDirectory {
    public let info: ArtifactBundleInfo
    public let rootDirectory: URL

    public init(at path: URL) throws {
        let infoPath = path.appending(path: "info.json")
        let data = try Data(contentsOf: infoPath)
        let info = try JSONDecoder().decode(ArtifactBundleInfo.self, from: data)

        self.info = info
        self.rootDirectory = path
    }
}

public struct ArtifactBundleInfo: Codable, Hashable {
    public var schemaVersion: String
    public var artifacts: [String: Artifact]

    public init(schemaVersion: String, artifacts: [String : Artifact]) {
        self.schemaVersion = schemaVersion
        self.artifacts = artifacts
    }
}

public struct Artifact: Codable, Hashable {
    public var version: String
    public var type: String
    public var variants: Set<ArtifactVariant>

    public init(version: String, type: String, variants: Set<ArtifactVariant>) {
        self.version = version
        self.type = type
        self.variants = variants
    }
}

public struct ArtifactVariant: Codable, Hashable {
    public var path: String
    public var supportedTriples: [String]

    public init(path: String, supportedTriples: [String]) {
        self.path = path
        self.supportedTriples = supportedTriples
    }
}
