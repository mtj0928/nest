import Foundation

public struct ExecutableBinary {
    public var commandName: String
    public var binaryPath: URL
    public var gitURL: GitURL
    public var version: String
    public var manufacturer: ExecutableManufacturer

    public init(commandName: String, binaryPath: URL, gitURL: GitURL, version: String, manufacturer: ExecutableManufacturer) {
        self.commandName = commandName
        self.binaryPath = binaryPath
        self.gitURL = gitURL
        self.version = version
        self.manufacturer = manufacturer
    }
}

public enum ExecutableManufacturer {
    case artifactBundle(fileName: String)
    case localBuild
}
