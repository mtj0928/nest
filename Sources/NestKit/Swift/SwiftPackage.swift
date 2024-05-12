import Foundation
import Logging

public struct SwiftPackage {
    let rootDirectory: URL
    let logger: Logger

    public init(at rootDirectory: URL, logger: Logger) {
        self.rootDirectory = rootDirectory
        self.logger = logger
    }

    public func executableFile(name: String) -> URL {
        rootDirectory.appending(components: ".build", "release", name)
    }

    public func buildForRelease() async throws {
        try await SwiftCommand(currentDirectoryURL: rootDirectory, logger: logger).buildForRelease()
    }

    public func description() async throws -> SwiftPackageDescription {
        try await SwiftCommand(currentDirectoryURL: rootDirectory, logger: logger).description()
    }
}
