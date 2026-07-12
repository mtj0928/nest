import Foundation
import Logging
import NestCLI
import NestKit
import NestTestHelpers
import Testing

struct ArtfactBundleFetcherTests {
    let logger = Logger(label: "test")
    let nestDirectory = NestDirectory(rootDirectory: URL(filePath: "/User/.nest"))
    let executorBuilder = MockExecutorBuilder { command, arguments in
        let command = ([command] + arguments).joined(separator: " ")
        switch command {
        case "/usr/bin/which swift":
            return "/usr/bin/swift"
        case "/usr/bin/swift -print-target-info":
            return """
                { "target": { "unversionedTriple": "arm64-apple-macosx" } }
                """
        case let command where command.hasPrefix("/usr/bin/swift package compute-checksum /tmp/nest-artifact-bundle-"):
            return "aaa"
        default:
            Issue.record("Unexpected command: \(command)")
            return ""
        }
    }
    let fileSystem = MockFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/User"),
        temporaryDirectory: URL(filePath: "/tmp")
    )

    init() {
        fileSystem.item = [
            "/": [
                "User": [:],
                "tmp": [:]
            ]
        ]
    }

    @Test(arguments: [
        (artifactBundlePath: artifactBundlePath, expectedBinaryPath: URL(filePath: "/tmp/nest/artifactbundle/foo.artifactbundle/foo-1.0.0-macosx/bin/foo")),
        (artifactBundlePath: withoutArtifactBundleFolderPath, expectedBinaryPath: URL(filePath: "/tmp/nest/artifactbundle/foo-1.0.0-macosx/bin/foo"))
    ])
    func fetchArtifactBundleWithZIPURL(artifactBundlePath: URL, expectedBinaryPath: URL) async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")

        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: try Data(contentsOf: artifactBundlePath)]

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )
        let result = try await fetcher.downloadArtifactBundle(url: zipURL, checksum: .skip)
        #expect(result == [ExecutableBinary(
            commandName: "foo",
            binaryPath: expectedBinaryPath,
            version: "1.0.0",
            manufacturer: .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: zipURL, repository: nil))
        )])
    }

    @Test
    func downloadArtifactBundleThrowsOnChecksumMismatch() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: try Data(contentsOf: artifactBundlePath)]
        let zipCache = ArtifactBundleZIPCache(
            directory: URL(filePath: "/User/Library/Caches/nest/artifact-bundle-zips")
        )

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(
                httpClient: httpClient,
                registryConfigs: nil,
                logger: logger
            ),
            artifactBundleZIPCacheOption: .enableCache(zipCache),
            logger: logger
        )

        await #expect(throws: ArtifactBundleFetcherError.self) {
            try await fetcher.downloadArtifactBundle(
                url: zipURL,
                checksum: .needsCheck(expected: "different-checksum")
            )
        }

        // The destination directory must not be populated when the checksum
        // verification fails: unzip must not run before verification.
        let destination = workingDirectory.appending(component: zipURL.fileNameWithoutPathExtension)
        #expect(!fileSystem.fileExists(atPath: destination.path()))
        #expect(!fileSystem.fileExists(atPath: zipCache.fileURL(for: zipURL).path()))
    }

    @Test
    func unresolvableChecksumThrowsOnZipDownload() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: try Data(contentsOf: artifactBundlePath)]

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )

        await #expect(throws: ChecksumOptionError.mutuallyExclusiveFlags) {
            try await fetcher.downloadArtifactBundle(
                url: zipURL,
                checksum: .unresolvable(.mutuallyExclusiveFlags)
            )
        }
    }

    @Test
    func missingChecksumContinuesZipDownloadForMigration() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: try Data(contentsOf: artifactBundlePath)]

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )

        let result = try await fetcher.downloadArtifactBundle(
            url: zipURL,
            checksum: .warnOnMissingChecksum(target: "owner/repo")
        )

        #expect(result == [ExecutableBinary(
            commandName: "foo",
            binaryPath: URL(filePath: "/tmp/nest/artifactbundle/foo.artifactbundle/foo-1.0.0-macosx/bin/foo"),
            version: "1.0.0",
            manufacturer: .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: zipURL, repository: nil))
        )])
    }

    @Test
    func missingChecksumThrowsOnZipDownloadInStrictMode() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: try Data(contentsOf: artifactBundlePath)]

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )

        await #expect(throws: ChecksumOptionError.missingChecksum(target: "owner/repo")) {
            try await fetcher.downloadArtifactBundle(
                url: zipURL,
                checksum: .unresolvable(.missingChecksum(target: "owner/repo"))
            )
        }
    }

    @Test(arguments: [
        (artifactBundlePath: artifactBundlePath, expectedBinaryPath: URL(filePath: "/tmp/nest/repo/foo.artifactbundle/foo-1.0.0-macosx/bin/foo")),
        (artifactBundlePath: withoutArtifactBundleFolderPath, expectedBinaryPath: URL(filePath: "/tmp/nest/repo/foo-1.0.0-macosx/bin/foo"))
    ])
    func fetchArtifactBundleFromGitRepository(artifactBundlePath: URL, expectedBinaryPath: URL) async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")

        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        let apiResponse = try #require("""
        {
                    "tag_name": "1.0.0",
                    "assets": [
                        {
                            "name": "artifactbundle.zip",
                            "browser_download_url": "\(zipURL.absoluteString)"
                        }
                    ]
                }
        """.data(using: .utf8))
        httpClient.dummyData = try [
            zipURL: Data(contentsOf: artifactBundlePath),
            #require(URL(string: "https://api.github.com/repos/owner/repo/releases/tags/1.0.0")): apiResponse
        ]

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )
        let gitRepositoryURL = try #require(URL(string: "https://github.com/owner/repo"))
        let result = try await fetcher.fetchArtifactBundleFromGitRepository(
            for: gitRepositoryURL,
            version: .tag("1.0.0"),
            artifactBundleZipFileName: nil,
            checksum: .printActual { checksum in
                #expect(checksum == "aaa")
            }
        )
        let expected = [ExecutableBinary(
            commandName: "foo",
            binaryPath: expectedBinaryPath,
            version: "1.0.0",
            manufacturer: .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(
                zipURL: zipURL,
                repository: Repository(reference: .url(gitRepositoryURL), version: "1.0.0")
            ))
        )]
        #expect(result == expected)
    }

    @Test
    func downloadArtifactBundleStoresZIPInUserScopeCache() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let zipData = try Data(contentsOf: artifactBundlePath)
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: zipData]
        let zipCache = ArtifactBundleZIPCache(directory: URL(filePath: "/User/Library/Caches/nest/artifact-bundle-zips"))

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .enableCache(zipCache),
            logger: logger
        )

        _ = try await fetcher.downloadArtifactBundle(url: zipURL, checksum: .skip)

        let cachedZIPURL = zipCache.fileURL(for: zipURL)
        #expect(try fileSystem.data(at: cachedZIPURL) == zipData)
    }

    @Test
    func downloadArtifactBundleRemovesOperationScopedTemporaryZIP() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: try Data(contentsOf: artifactBundlePath)]
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: httpClient),
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )

        _ = try await fetcher.downloadArtifactBundle(url: zipURL, checksum: .skip)

        let temporaryFiles = try fileSystem.contentsOfDirectory(atPath: fileSystem.temporaryDirectory.path())
        #expect(!temporaryFiles.contains(where: { $0.hasPrefix("nest-artifact-bundle-") }))
        #expect(!fileSystem.fileExists(atPath: fileSystem.temporaryDirectory.appending(component: zipURL.lastPathComponent).path()))
    }

    @Test
    func downloadArtifactBundleUsesUserScopeCacheBeforeNetwork() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let zipData = try Data(contentsOf: artifactBundlePath)
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        let zipCache = ArtifactBundleZIPCache(directory: URL(filePath: "/User/Library/Caches/nest/artifact-bundle-zips"))
        let cachedZIPURL = zipCache.fileURL(for: zipURL)
        try fileSystem.createDirectory(at: cachedZIPURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileSystem.write(zipData, to: cachedZIPURL)

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .enableCache(zipCache),
            logger: logger
        )

        let result = try await fetcher.downloadArtifactBundle(url: zipURL, checksum: .skip)

        #expect(result == [ExecutableBinary(
            commandName: "foo",
            binaryPath: URL(filePath: "/tmp/nest/artifactbundle/foo.artifactbundle/foo-1.0.0-macosx/bin/foo"),
            version: "1.0.0",
            manufacturer: .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: zipURL, repository: nil))
        )])
    }

    @Test
    func downloadArtifactBundleReplacesUnusableUserScopeCache() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let zipData = try Data(contentsOf: artifactBundlePath)
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        httpClient.dummyData = [zipURL: zipData]
        let cacheDirectory = URL(filePath: "/User/Library/Caches/nest/artifact-bundle-zips")
        let zipCache = ArtifactBundleZIPCache(directory: cacheDirectory)
        let cachedZIPURL = zipCache.fileURL(for: zipURL)
        try fileSystem.createDirectory(
            at: cachedZIPURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileSystem.write(Data("invalid ZIP".utf8), to: cachedZIPURL)

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(
                httpClient: httpClient,
                registryConfigs: nil,
                logger: logger
            ),
            artifactBundleZIPCacheOption: .enableCache(zipCache),
            logger: logger
        )

        let result = try await fetcher.downloadArtifactBundle(url: zipURL, checksum: .skip)

        #expect(result == [ExecutableBinary(
            commandName: "foo",
            binaryPath: URL(filePath: "/tmp/nest/artifactbundle/foo.artifactbundle/foo-1.0.0-macosx/bin/foo"),
            version: "1.0.0",
            manufacturer: .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: zipURL, repository: nil))
        )])
        #expect(try fileSystem.data(at: cachedZIPURL) == zipData)
    }

    @Test
    func downloadArtifactBundlePreservesUserScopeCacheWhenDestinationIsUnavailable() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let zipData = try Data(contentsOf: artifactBundlePath)
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        let zipCache = ArtifactBundleZIPCache(directory: URL(filePath: "/User/Library/Caches/nest/artifact-bundle-zips"))
        let cachedZIPURL = zipCache.fileURL(for: zipURL)
        try fileSystem.createDirectory(at: cachedZIPURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileSystem.write(zipData, to: cachedZIPURL)
        fileSystem.unzipError = .destinationUnavailable

        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: httpClient),
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .enableCache(zipCache),
            logger: logger
        )

        await #expect(throws: MockFileSystem.MockFileSystemError.destinationUnavailable) {
            try await fetcher.downloadArtifactBundle(url: zipURL, checksum: .skip)
        }
        #expect(try fileSystem.data(at: cachedZIPURL) == zipData)
    }

    @Test
    func downloadArtifactBundleDoesNotUseUserScopeCacheWhenDisabled() async throws {
        let workingDirectory = URL(filePath: "/tmp/nest")
        let zipURL = try #require(URL(string: "https://example.com/artifactbundle.zip"))
        let zipData = try Data(contentsOf: artifactBundlePath)
        let httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        let zipCache = ArtifactBundleZIPCache(directory: URL(filePath: "/User/Library/Caches/nest/artifact-bundle-zips"))
        let cachedZIPURL = zipCache.fileURL(for: zipURL)
        try fileSystem.createDirectory(at: cachedZIPURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileSystem.write(zipData, to: cachedZIPURL)

        let fileDownloader = NestFileDownloader(httpClient: httpClient)
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: workingDirectory,
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: fileDownloader,
            nestInfoController: NestInfoController(directory: nestDirectory, fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: httpClient, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )

        await #expect(throws: (any Error).self) {
            try await fetcher.downloadArtifactBundle(url: zipURL, checksum: .skip)
        }
    }
}

let fixturePath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Resources")
    .appendingPathComponent("Fixtures")

let artifactBundlePath = fixturePath.appendingPathComponent("foo.artifactbundle.zip")
let withoutArtifactBundleFolderPath = fixturePath.appendingPathComponent("without.artifactbundle.folder.artifactbundle.zip")
