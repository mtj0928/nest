import Foundation
import Logging
import NestKit

public struct ArtifactBundleFetcher {
    private let workingDirectory: URL
    private let fileManager: FileManager
    private let zipFileDownloader: ZipFileDownloader
    private let nestInfoRepository: NestInfoRepository
    private let repositoryClientBuilder: GitRepositoryClientBuilder
    private let logger: Logger

    public init(
        workingDirectory: URL,
        fileManager: FileManager,
        zipFileDownloader: ZipFileDownloader,
        nestInfoRepository: NestInfoRepository,
        repositoryClientBuilder: GitRepositoryClientBuilder,
        logger: Logger
    ) {
        self.workingDirectory = workingDirectory
        self.fileManager = fileManager
        self.zipFileDownloader = zipFileDownloader
        self.nestInfoRepository = nestInfoRepository
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
        let nestInfo = nestInfoRepository.getInfo()

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
            .flatMap { bundle in bundle.binaries(of: triple) }
    }

    public func downloadArtifactBundle(url: URL) async throws -> [ExecutableBinary] {
        let nestInfo = nestInfoRepository.getInfo()
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
            .flatMap { bundle in bundle.binaries(of: triple) }
    }
}


public enum ArtifactBundleFetcherError: LocalizedError {
    case noCandidates

    public var errorDescription: String? {
        switch self {
        case .noCandidates: "No candidates for artifact bundle in the repository, please specify the file name."
        }
    }
}
