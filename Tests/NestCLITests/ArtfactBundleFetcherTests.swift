import Testing
import NestCLI
import NestKit
import Foundation
import Logging
import NestTestHelpers

struct ArtfactBundleFetcherTests {
    let logger = Logger(label: "test")
    let nestDirectory = NestDirectory(rootDirectory: URL(filePath: "/User/.nest"))
    let executorBuilder = MockExecutorBuilder(dummy: [
        "/usr/bin/which swift": "/usr/bin/swift",
        "/usr/bin/swift -print-target-info": """
                { "target": { "unversionedTriple": "arm64-apple-macosx" } }
                """,
        "/usr/bin/swift package compute-checksum /tmp/artifactbundle.zip": "aaa",
        "/usr/bin/swift package compute-checksum /tmp/repo.zip": "aaa"
    ])
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

    @Test
    func fetchArtifactBundleWithZIPURL() async throws {
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
            repositoryClientBuilder: GitRepositoryClientBuilder(httpClient: httpClient, serverConfigs: nil, logger: logger),
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
    func fetchArtifactBundleFromGitRepository() async throws {
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
            repositoryClientBuilder: GitRepositoryClientBuilder(httpClient: httpClient, serverConfigs: nil, logger: logger),
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
            binaryPath: URL(filePath: "/tmp/nest/repo/foo.artifactbundle/foo-1.0.0-macosx/bin/foo"),
            version: "1.0.0",
            manufacturer: .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(
                zipURL: zipURL,
                repository: Repository(reference: .url(gitRepositoryURL), version: "1.0.0")
            ))
        )]
        #expect(result == expected)
    }
}

let fixturePath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Resources")
    .appendingPathComponent("Fixtures")

let artifactBundlePath = fixturePath.appendingPathComponent("foo.artifactbundle.zip")
