import Foundation
import Logging
import NestKit

public struct ArtifactBundleFetcher {
    private let workingDirectory: URL
    private let executorBuilder: any ProcessExecutorBuilder
    private let fileSystem: any FileSystem
    private let fileDownloader: any FileDownloader
    private let nestInfoController: NestInfoController
    private let assetRegistryClientBuilder: AssetRegistryClientBuilder
    private let checksumCalculator: any ChecksumCalculator
    private let tripleDetector: TripleDetector
    private let artifactBundleZIPCacheOption: ArtifactBundleZIPCacheOption
    private let logger: Logger

    public init(
        workingDirectory: URL,
        executorBuilder: some ProcessExecutorBuilder,
        fileSystem: some FileSystem,
        fileDownloader: some FileDownloader,
        nestInfoController: NestInfoController,
        assetRegistryClientBuilder: AssetRegistryClientBuilder,
        artifactBundleZIPCacheOption: ArtifactBundleZIPCacheOption,
        logger: Logger
    ) {
        self.workingDirectory = workingDirectory
        self.executorBuilder = executorBuilder
        self.fileSystem = fileSystem
        self.fileDownloader = fileDownloader
        self.nestInfoController = nestInfoController
        self.assetRegistryClientBuilder = assetRegistryClientBuilder
        self.checksumCalculator = SwiftChecksumCalculator(swift: SwiftCommand(executor: executorBuilder.build()))
        self.tripleDetector = TripleDetector(swiftCommand: SwiftCommand(executor: executorBuilder.build()))
        self.artifactBundleZIPCacheOption = artifactBundleZIPCacheOption
        self.logger = logger
    }
    
    /// Fetched an artifact bundle from the specified git repository.
    /// - Parameters:
    ///   - url: A url of a git repository
    ///   - version: A version which should be
    ///   - artifactBundleZipFileName: A name of artifact bundle ZIP file.
    ///   - checksum: An option for checksum validation.
    ///   When it is `nil`, this function tries to resolve a file name by accessing Web API.
    public func fetchArtifactBundleFromGitRepository(
        for gitURL: URL,
        version: GitVersion,
        artifactBundleZipFileName: String?,
        checksum: ChecksumOption
    ) async throws -> [ExecutableBinary] {
        let resolvedAsset = try await resolveAsset(
            from: gitURL,
            version: version,
            artifactBundleZipFileName: artifactBundleZipFileName
        )
        let nestInfo = nestInfoController.getInfo()

        if ArtifactDuplicatedDetector.isAlreadyInstalled(zipURL: resolvedAsset.zipURL, in: nestInfo) {
            throw NestCLIError.alreadyInstalled
        }

        logger.info("📦 Found an artifact bundle, \(resolvedAsset.zipURL.lastPathComponent), for \(gitURL.lastPathComponent).")

        // Reset the existing directory.
        let repositoryDirectory = workingDirectory.appending(component: gitURL.fileNameWithoutPathExtension)
        try fileSystem.removeItemIfExists(at: repositoryDirectory)

        try await downloadZIPFile(from: resolvedAsset.zipURL, to: repositoryDirectory, checksum: checksum)

        // Get the current triple.
        let triple = try await tripleDetector.detect()
        logger.debug("The current triple is \(triple)")

        let repository = Repository(reference: .url(gitURL), version: resolvedAsset.tagName)
        let sourceInfo = ArtifactBundleSourceInfo(zipURL: resolvedAsset.zipURL, repository: repository)
        let artifactBundlePaths = try fileSystem.child(extension: "artifactbundle", at: repositoryDirectory)

        guard !artifactBundlePaths.isEmpty else {
            logger.warning("⚠️ The zip file of \(gitURL.lastPathComponent) doesn't follow the artifact bundle spec (SE-0305), so nest tries to install it using fallback behavior. Please contact the repository owner if possible.")
            // If Info.json and executable file exist, nest will attempt to install executable file.
            let bundle = try ArtifactBundle.load(at: repositoryDirectory, sourceInfo: sourceInfo, fileSystem: fileSystem)
            return try bundle.binaries(of: triple)
        }
        return try artifactBundlePaths
            .map { try ArtifactBundle.load(at: $0, sourceInfo: sourceInfo, fileSystem: fileSystem) }
            .flatMap { try $0.binaries(of: triple) }
    }

    public func downloadArtifactBundle(url: URL, checksum: ChecksumOption) async throws -> [ExecutableBinary] {
        let nestInfo = nestInfoController.getInfo()
        if ArtifactDuplicatedDetector.isAlreadyInstalled(zipURL: url, in: nestInfo) {
            throw NestCLIError.alreadyInstalled
        }

        let directory = workingDirectory.appending(component: url.fileNameWithoutPathExtension)
        try fileSystem.removeItemIfExists(at: directory)

        try await downloadZIPFile(from: url, to: directory, checksum: checksum)

        // Get the current triple.
        let triple = try await tripleDetector.detect()
        logger.debug("The current triple is \(triple)")

        let sourceInfo = ArtifactBundleSourceInfo(zipURL: url, repository: nil)
        let artifactBundlePaths = try fileSystem.child(extension: "artifactbundle", at: directory)

        guard !artifactBundlePaths.isEmpty else {
            logger.warning("⚠️ \(url.lastPathComponent) doesn't follow the artifact bundle spec (SE-0305), so nest tries to install it using fallback behavior. Please contact the zip file owner if possible.")
            // If Info.json and executable file exist, nest will attempt to install executable file.
            let bundle = try ArtifactBundle.load(at: directory, sourceInfo: sourceInfo, fileSystem: fileSystem)
            return try bundle.binaries(of: triple)
        }
        return try artifactBundlePaths
            .map { try ArtifactBundle.load(at: $0, sourceInfo: sourceInfo, fileSystem: fileSystem) }
            .flatMap { try $0.binaries(of: triple) }
    }

    private func resolveAsset(
        from url: URL,
        version: GitVersion,
        artifactBundleZipFileName fileName: String?
    ) async throws -> ResolvedAsset {
        if let fileName, case .tag(let version) = version {
            let artifactBundleZipURL = GitHubURLBuilder.assetDownloadURL(url, version: version, fileName: fileName)
            logger.debug("Resolved artifact bundle zip URL: \(artifactBundleZipURL.absoluteString).")
            let asset = ResolvedAsset(zipURL: artifactBundleZipURL, fileName: fileName, tagName: version)
            return asset
        }

        let assetRegistryClient = assetRegistryClientBuilder.build(for: url)
        let assetInfo = try await assetRegistryClient.fetchAssets(repositoryURL: url, version: version)
        // Choose an asset which may be an artifact bundle.
        guard let selectedAsset = ArtifactBundleAssetSelector().selectArtifactBundle(
            from: assetInfo.assets,
            fileName: fileName
        ) else {
            throw ArtifactBundleFetcherError.noCandidates
        }
        return ResolvedAsset(
            zipURL: selectedAsset.url,
            fileName: selectedAsset.fileName,
            tagName: assetInfo.tagName
        )
    }

    private func downloadZIPFile(from url: URL, to destination: URL, checksum: ChecksumOption) async throws {
        // Surface an unresolved checksum requirement before spending bandwidth
        // on a download whose archive we cannot accept anyway.
        if url.needsUnzip, case .unresolvable(let error) = checksum {
            throw error
        }
        if !url.needsUnzip {
            let downloadedFilePath = try await fileDownloader.download(url: url)
            if case .unresolvable(let error) = checksum {
                throw error
            }
            try fileSystem.copyItem(at: downloadedFilePath, to: destination)
            return
        }

        let cacheFilePath = artifactBundleZIPCacheOption.cacheFileURL(for: url)
        let temporaryZIPFilePath = fileSystem.temporaryDirectory.appending(
            component: "nest-artifact-bundle-\(UUID().uuidString).zip"
        )
        defer { try? fileSystem.removeItemIfExists(at: temporaryZIPFilePath) }
        if let cacheFilePath,
           fileSystem.fileExists(atPath: cacheFilePath.path()) {
            logger.info("🔄 Reusing the artifact bundle ZIP from the user cache.")
            logger.debug("The cached artifact bundle ZIP is at \(cacheFilePath.path()).")
            do {
                try await prepareZIPFile(
                    at: cacheFilePath,
                    temporaryZIPFilePath: temporaryZIPFilePath,
                    destination: destination,
                    checksum: checksum
                )
                return
            } catch {
                if !error.invalidatesArtifactBundleZIPCache {
                    throw error
                }
                logger.warning(
                    """
                    ⚠️ Cached artifact bundle ZIP is unusable and will be downloaded again: \
                    \(error.localizedDescription)
                    """
                )
                try? fileSystem.removeItemIfExists(at: cacheFilePath)
                try fileSystem.removeItemIfExists(at: destination)
            }
        }

        logger.info("🌐 Downloading the artifact bundle ZIP at \(url.absoluteString)...")
        let downloadedZIPFilePath = try await fileDownloader.download(url: url)
        try await prepareZIPFile(
            at: downloadedZIPFilePath,
            temporaryZIPFilePath: temporaryZIPFilePath,
            destination: destination,
            checksum: checksum
        )

        if let cacheFilePath {
            storeZIPFileInCache(at: temporaryZIPFilePath, to: cacheFilePath)
        }
    }

    private func prepareZIPFile(
        at sourceURL: URL,
        temporaryZIPFilePath: URL,
        destination: URL,
        checksum: ChecksumOption
    ) async throws {
        try fileSystem.removeItemIfExists(at: temporaryZIPFilePath)
        try fileSystem.copyItem(at: sourceURL, to: temporaryZIPFilePath)

        switch checksum {
        case .unresolvable(let error):
            throw error
        case .warnOnMissingChecksum(let target):
            // TODO: Make missing checksums a hard error after the migration period ends.
            // Keep this warning path only until existing CI users have had enough time
            // to populate nestfile checksums with `nest update-nestfile`.
            let calculatedChecksum = try await checksumCalculator.calculate(temporaryZIPFilePath.path())
            logger.warning(
                """

                🚨🚨🚨  CHECKSUM MISSING - UNVERIFIED ARTIFACT BUNDLE  🚨🚨🚨

                nest is installing "\(target)" without checksum verification.
                This is allowed temporarily for migration, but it will become an error in a future release.

                Add this checksum to the target in your nestfile:
                  checksum: \(calculatedChecksum)

                Recommended:
                  nest update-nestfile <path>

                Temporary CI escape hatch:
                  nest bootstrap <path> --checksum-policy skip
                  nest run --checksum-policy skip ...

                🚨🚨🚨  CHECKSUM MISSING - UNVERIFIED ARTIFACT BUNDLE  🚨🚨🚨
                """,
                metadata: .color(.yellow)
            )
        case .needsCheck(let expectedChecksum):
            let calculatedChecksum = try await checksumCalculator.calculate(temporaryZIPFilePath.path())
            if expectedChecksum != calculatedChecksum {
                throw ArtifactBundleFetcherError.checksumMismatch(
                    expected: expectedChecksum,
                    actual: calculatedChecksum
                )
            }
        case .printActual(let handler):
            let calculatedChecksum = try await checksumCalculator.calculate(temporaryZIPFilePath.path())
            handler(calculatedChecksum)
        case .skip:
            break
        }

        try fileSystem.unzip(at: temporaryZIPFilePath, to: destination)
    }

    private func storeZIPFileInCache(at sourceURL: URL, to cacheFilePath: URL) {
        do {
            try fileSystem.copyItemAtomicallyReplacingDestination(at: sourceURL, to: cacheFilePath)
            logger.info("📦 Cached artifact bundle ZIP.")
            logger.debug("The artifact bundle ZIP was cached at \(cacheFilePath.path()).")
        } catch {
            logger.warning("⚠️ Failed to cache the artifact bundle ZIP: \(error.localizedDescription)")
        }
    }
}

extension ArtifactBundleZIPCacheOption {
    fileprivate func cacheFileURL(for remoteURL: URL) -> URL? {
        switch self {
        case .enableCache(let artifactBundleZIPCache): artifactBundleZIPCache.fileURL(for: remoteURL)
        case .disableCache: nil
        }
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

private extension Error {
    var invalidatesArtifactBundleZIPCache: Bool {
        if self is InvalidZIPArchiveError {
            return true
        }
        guard let artifactBundleFetcherError = self as? ArtifactBundleFetcherError else {
            return false
        }
        return switch artifactBundleFetcherError {
        case .checksumMismatch: true
        default: false
        }
    }
}

private struct ResolvedAsset {
    var zipURL: URL
    var fileName: String
    var tagName: String
}
