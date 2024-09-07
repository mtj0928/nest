import Foundation
import Logging

/// A data structure representing Swift Package.
public struct SwiftPackage {
    let rootDirectory: URL
    let logger: Logger

    public init(at rootDirectory: URL, logger: Logger) {
        self.rootDirectory = rootDirectory
        self.logger = logger
    }

    /// Returns a URL representing executable file.
    public func executableFile(name: String) -> URL {
        rootDirectory.appending(components: ".build", "release", name)
    }

    /// Build the package for release.
    public func buildForRelease() async throws {
        try await SwiftCommand(currentDirectoryURL: rootDirectory, logger: logger).buildForRelease()
    }

    /// Executes describe command of Swift Package.
    public func description() async throws -> SwiftPackageDescription {
        try await SwiftCommand(currentDirectoryURL: rootDirectory, logger: logger).description()
    }
}
