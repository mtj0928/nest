import Foundation

/// A data structure corresponding to info.json in artifact bundle.
///
///[Definition in Swift evolution]( https://github.com/swiftlang/swift-evolution/blob/main/proposals/0305-swiftpm-binary-target-improvements.md#artifact-bundle-manifest)
public struct ArtifactBundleInfo: Codable, Hashable, Sendable {
    public var schemaVersion: String
    /// A map of artifacts. The key is an identifier of an artifact.
    /// In most cases, the identifier is the same command name.
    public var artifacts: [String: Artifact]

    public init(schemaVersion: String, artifacts: [String : Artifact]) {
        self.schemaVersion = schemaVersion
        self.artifacts = artifacts
    }
}

public struct Artifact: Codable, Hashable, Sendable {
    /// A version of the asrtifact
    public var version: String

    /// A type of the artifact.
    /// Current only "executable" is passed.
    public var type: String

    // Variants of the artifact.
    public var variants: Set<ArtifactVariant>

    public init(version: String, type: String, variants: Set<ArtifactVariant>) {
        self.version = version
        self.type = type
        self.variants = variants
    }
}

/// A data structure representing an executable in an artifact bundle.
public struct ArtifactVariant: Codable, Hashable, Sendable {
    /// A path to the executable file
    public var path: String

    /// A tripes which the executable supports
    public var supportedTriples: [String]

    public init(path: String, supportedTriples: [String]) {
        self.path = path
        self.supportedTriples = supportedTriples
    }
}
