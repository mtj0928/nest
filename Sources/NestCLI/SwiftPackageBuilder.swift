import Foundation
import Logging
import NestKit

public struct SwiftPackageBuilder {

    private let workingDirectory: URL
    private let fileManager: FileManager
    private let repositoryClientBuilder: GitRepositoryClientBuilder
    private let logger: Logger

    public init(
        workingDirectory: URL,
        fileManager: FileManager,
        repositoryClientBuilder: GitRepositoryClientBuilder,
        logger: Logger
    ) {
        self.workingDirectory = workingDirectory
        self.fileManager = fileManager
        self.repositoryClientBuilder = repositoryClientBuilder
        self.logger = logger
    }

    public func build(gitURL: GitURL, version: GitVersion) async throws -> [ExecutableBinary] {
        // Reset the existing directory.
        let repositoryDirectory = workingDirectory.appending(component: gitURL.repositoryName)
        try fileManager.removeItemIfExists(at: repositoryDirectory)

        // Resolve a tag or version.
        let tagOrVersion = try await resolveTagOrVersion(gitURL: gitURL, version: version)
        logger.debug("The tag or version is \(tagOrVersion ?? "nil")")

        // Clone the repository.
        logger.info("🔄 Cloning \(gitURL.repositoryName)...")
        try await GitCommand(logger: logger).clone(repositoryURL: gitURL, tag: tagOrVersion, to: repositoryDirectory)

        // Get the current branch.
        let branch = try await GitCommand(currentDirectoryURL: repositoryDirectory, logger: logger).currentBranch()

        // Build the repository
        logger.info("🔨 Building \(gitURL.repositoryName) for \(tagOrVersion ?? branch)...")
        let swiftPackage = SwiftPackage(at: repositoryDirectory, logger: logger)
        try await swiftPackage.buildForRelease()

        // Extract the built binaries.
        let executableNames = try await swiftPackage.description().executableNames
        return executableNames.map { executableName in
            ExecutableBinary(
                commandName: executableName,
                binaryPath: swiftPackage.executableFile(name: executableName),
                gitURL: gitURL,
                version: tagOrVersion ?? branch,
                manufacturer: .localBuild
            )
        }
    }

    private func resolveTagOrVersion(gitURL: GitURL, version: GitVersion) async throws -> String? {
        switch (gitURL, version) {
        case (.url(let url), .latestRelease):
            let repositoryClient = repositoryClientBuilder.build(for: url)
            return try? await repositoryClient.fetchAssets(repositoryURL: url, version: .latestRelease).tagName

        case (.ssh, .latestRelease):
            return nil

        case (_, .tag(let tagName)):
            return tagName
        }
    }
}
