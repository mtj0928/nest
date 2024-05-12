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
        public var binaryPath: String
        public var isLinked: Bool
        public var version: String

        public init(binaryPath: String, isLinked: Bool, version: String) {
            self.binaryPath = binaryPath
            self.isLinked = isLinked
            self.version = version
        }
    }
}
