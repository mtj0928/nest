import Foundation
import Logging
import NestKit

public struct SwiftPackageBuilder {

    private let workingDirectory: URL
    private let fileSystem: any FileSystem
    private let nestInfoController: NestInfoController
    private let repositoryClientBuilder: GitRepositoryClientBuilder
    private let logger: Logger

    public init(
        workingDirectory: URL,
        fileSystem: some FileSystem,
        nestInfoController: NestInfoController,
        repositoryClientBuilder: GitRepositoryClientBuilder,
        logger: Logger
    ) {
        self.workingDirectory = workingDirectory
        self.fileSystem = fileSystem
        self.nestInfoController = nestInfoController
        self.repositoryClientBuilder = repositoryClientBuilder
        self.logger = logger
    }

    public func build(gitURL: GitURL, version: GitVersion) async throws -> [ExecutableBinary] {
        // Reset the existing directory.
        let repositoryDirectory = workingDirectory.appending(component: gitURL.repositoryName)
        try fileSystem.removeItemIfExists(at: repositoryDirectory)

        // Resolve a tag or version.
        let tagOrVersion = try await resolveTagOrVersion(gitURL: gitURL, version: version)
        logger.debug("The tag or version is \(tagOrVersion ?? "nil")")

        let info = nestInfoController.getInfo()
        if ArtifactDuplicatedDetector.isAlreadyInstalled(url: gitURL, version: tagOrVersion, in: info) {
            throw NestCLIError.alreadyInstalled
        }

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
            let version = tagOrVersion ?? branch
            return ExecutableBinary(
                commandName: executableName,
                binaryPath: swiftPackage.executableFile(name: executableName),
                version: version,
                manufacturer: .localBuild(repository: Repository(reference: gitURL, version: version))
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
