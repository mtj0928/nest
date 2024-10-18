import Foundation

/// A data structure representing executable target.
public struct ExecutableBinary: Codable, Sendable, Equatable {
    public var commandName: String
    public var binaryPath: URL
    public var version: String
    public var manufacturer: ExecutableManufacturer

    public var parentDirectory: URL {
        binaryPath.deletingLastPathComponent()
    }

    public init(commandName: String, binaryPath: URL, version: String, manufacturer: ExecutableManufacturer) {
        self.commandName = commandName
        self.binaryPath = binaryPath
        self.version = version
        self.manufacturer = manufacturer
    }
}

/// An enum representing manufacturer of an executable target
public enum ExecutableManufacturer: Codable, Sendable, Equatable, Hashable {
    /// A case where the executable target is from an artifact bundle
    case artifactBundle(sourceInfo: ArtifactBundleSourceInfo)

    /// A case where the executable target is built in the local environment
    case localBuild(repository: Repository)
}

/// Informations of artifact bundle.
public struct ArtifactBundleSourceInfo: Codable, Sendable, Equatable, Hashable {
    /// A url where the artifact bundle is located.
    public let zipURL: URL

    /// A repository of the artifact bundle. If the repository is not identified, the value can be `nil`.
    public let repository: Repository?

    public init(zipURL: URL, repository: Repository?) {
        self.zipURL = zipURL
        self.repository = repository
    }
}

public struct Repository: Codable, Sendable, Equatable, Hashable {
    public let reference: GitURL
    public let version: String

    public init(reference: GitURL, version: String) {
        self.reference = reference
        self.version = version
    }
}
