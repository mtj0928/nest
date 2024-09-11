import Foundation
import Logging
import NestKit

public struct ArtifactBundleFetcher {
    private let workingDirectory: URL
    private let fileManager: FileManager
    private let zipFileDownloader: ZipFileDownloader
    private let nestInfoController: NestInfoController
    private let repositoryClientBuilder: GitRepositoryClientBuilder
    private let logger: Logger

    public init(
        workingDirectory: URL,
        fileManager: FileManager,
        zipFileDownloader: ZipFileDownloader,
        nestInfoController: NestInfoController,
        repositoryClientBuilder: GitRepositoryClientBuilder,
        logger: Logger
    ) {
        self.workingDirectory = workingDirectory
        self.fileManager = fileManager
        self.zipFileDownloader = zipFileDownloader
        self.nestInfoController = nestInfoController
        self.repositoryClientBuilder = repositoryClientBuilder
        self.logger = logger
    }

    public func fetchArtifactBundleFromGitRepository(for url: URL, version: GitVersion) async throws -> [ExecutableBinary] {
        // Fetch asset information from the remove repository
        let repositoryClient = repositoryClientBuilder.build(for: url)
        let assetInfo = try await repositoryClient.fetchAssets(repositoryURL: url, version: version)

        // Choose an asset which may be an artifact bundle.
        guard let selectedAsset = ArtifactBundleAssetSelector().selectArtifactBundle(from: assetInfo.assets) else {
            throw ArtifactBundleFetcherError.noCandidates
        }
        let tagName = assetInfo.tagName
        let nestInfo = nestInfoController.getInfo()

        if ArtifactDuplicatedDetector.isAlreadyInstalled(zipURL: selectedAsset.url, in: nestInfo) {
            throw NestCLIError.alreadyInstalled
        }

        logger.info("📦 Found an artifact bundle, \(selectedAsset.fileName), for \(url.lastPathComponent).")

        // Reset the existing directory.
        let repositoryDirectory = workingDirectory.appending(component: url.fileNameWithoutPathExtension)
        try fileManager.removeItemIfExists(at: repositoryDirectory)

        // Download the artifact bundle
        logger.info("🌐 Downloading the artifact bundle of \(url.lastPathComponent)...")
        try await zipFileDownloader.download(url: selectedAsset.url, to: repositoryDirectory)
        logger.info("✅ Success to download the artifact bundle of \(url.lastPathComponent).", metadata: .color(.green))

        // Get the current triple.
        let triple = try await TripleDetector(logger: logger).detect()
        logger.debug("The current triple is \(triple)")

        return try fileManager.child(extension: "artifactbundle", at: repositoryDirectory)
            .map { artifactBundlePath in
                let repository = Repository(reference: .url(url), version: tagName)
                let sourceInfo = ArtifactBundleSourceInfo(zipURL: selectedAsset.url, repository: repository)
                return try ArtifactBundle(at: artifactBundlePath, sourceInfo: sourceInfo)
            }
            .flatMap { bundle in try bundle.binaries(of: triple) }
    }

    public func downloadArtifactBundle(url: URL) async throws -> [ExecutableBinary] {
        let nestInfo = nestInfoController.getInfo()
        if ArtifactDuplicatedDetector.isAlreadyInstalled(zipURL: url, in: nestInfo) {
            throw NestCLIError.alreadyInstalled
        }

        let directory = workingDirectory.appending(component: url.fileNameWithoutPathExtension)
        try fileManager.removeItemIfExists(at: directory)

        // Download the artifact bundle
        logger.info("🌐 Downloading the artifact bundle at \(url.absoluteString)...")
        try await zipFileDownloader.download(url: url, to: directory)
        logger.info("✅ Success to download the artifact bundle of \(url.lastPathComponent).", metadata: .color(.green))

        // Get the current triple.
        let triple = try await TripleDetector(logger: logger).detect()
        logger.debug("The current triple is \(triple)")

        return try fileManager.child(extension: "artifactbundle", at: directory)
            .compactMap { artifactBundlePath in
                let sourceInfo = ArtifactBundleSourceInfo(zipURL: url, repository: nil)
                return try ArtifactBundle(at: artifactBundlePath, sourceInfo: sourceInfo)
            }
            .flatMap { bundle in try bundle.binaries(of: triple) }
    }
}

extension ArtifactBundle {
    func binaries(of triple: String) throws -> [ExecutableBinary] {
        try info.artifacts.flatMap { name, artifact in
            let binaries = artifact.variants
                .filter { variant in variant.supportedTriples.contains(triple) }
                .map { variant in variant.path }
                .map { variantPath in rootDirectory.appending(path: variantPath) }
                .map { binaryPath in
                    ExecutableBinary(
                        commandName: name,
                        binaryPath: binaryPath,
                        version: artifact.version,
                        manufacturer: .artifactBundle(sourceInfo: sourceInfo)
                    )
                }
            if binaries.isEmpty {
                throw ArtifactBundleFetcherError.unsupportedTriple
            }
            return binaries
        }
    }
}

public enum ArtifactBundleFetcherError: LocalizedError {
    case noCandidates
    case unsupportedTriple

    public var errorDescription: String? {
        switch self {
        case .noCandidates: "No candidates for artifact bundle in the repository, please specify the file name."
        case .unsupportedTriple: "No binaries corresponding to the current triple."
        }
    }
}
