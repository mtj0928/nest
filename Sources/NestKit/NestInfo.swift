import Foundation

public struct NestInfo: Codable {
    public var version: String
    public var commands: [String: [Command]]

    public init(version: String, commands: [String: [Command]]) {
        self.version = version
        self.commands = commands
    }
}

extension NestInfo {
    public static let currentVersion = "1"

    public struct Command: Codable {
        public var version: String
        public var binaryPath: String
        public var resourcePaths: [String]
        public var manufacturer: ExecutableManufacturer

        public init(version: String, binaryPath: String, resourcePaths: [String],  manufacturer: ExecutableManufacturer) {
            self.version = version
            self.binaryPath = binaryPath
            self.resourcePaths = resourcePaths
            self.manufacturer = manufacturer
        }
    }
}
