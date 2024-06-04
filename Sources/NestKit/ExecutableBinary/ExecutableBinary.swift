import Foundation

public struct ExecutableBinary: Codable {
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

public enum ExecutableManufacturer: Codable {
    case artifactBundle(sourceInfo: ArtifactBundleSourceInfo)
    case localBuild(repository: Repository)
}

public struct ArtifactBundleSourceInfo: Codable {
    public let zipURL: URL
    public let repository: Repository?

    public init(zipURL: URL, repository: Repository?) {
        self.zipURL = zipURL
        self.repository = repository
    }
}

public struct Repository: Codable {
    public let reference: GitURL
    public let version: String

    public init(reference: GitURL, version: String) {
        self.reference = reference
        self.version = version
    }
}
