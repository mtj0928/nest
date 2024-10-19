import Foundation
import Logging

/// A data structure representing Swift Package.
public struct SwiftPackage {
    let rootDirectory: URL
    let executorBuilder: any ProcessExecutorBuilder

    public init(
        at rootDirectory: URL,
        executorBuilder: any ProcessExecutorBuilder
    ) {
        self.rootDirectory = rootDirectory
        self.executorBuilder = executorBuilder
    }

    /// Returns a URL representing executable file.
    public func executableFile(name: String) -> URL {
        rootDirectory.appending(components: ".build", "release", name)
    }

    /// Build the package for release.
    public func buildForRelease() async throws {
        try await swift.buildForRelease()
    }

    /// Executes describe command of Swift Package.
    public func description() async throws -> SwiftPackageDescription {
        try await swift.description()
    }

    private var swift: SwiftCommand {
        SwiftCommand(executor: executorBuilder.build(currentDirectory: rootDirectory))
    }
}
