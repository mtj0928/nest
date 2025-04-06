import Foundation
import Logging
import NestCLI
@testable import NestKit
import NestTestHelpers
import Testing

struct NestfileControllerTests {
    let fileSystem: MockFileSystem
    let httpClient: MockHTTPClient
    let processExecutor = MockProcessExecutor(dummy: [
        "/usr/bin/which swift": "/usr/bin/swift",
        "/usr/bin/swift package compute-checksum /tmp/foo.artifacatbundle.zip": "aaa",
    ])

    init() {
        fileSystem = MockFileSystem(
            homeDirectoryForCurrentUser: URL(filePath: "/User"),
            temporaryDirectory: URL(filePath: "/tmp")
        )
        httpClient = MockHTTPClient(mockFileSystem: fileSystem)
        fileSystem.item = [
            "/": [
                "User": .directory,
                "tmp": .directory
            ]
        ]
    }

    @Test
    func update() async throws {
        let zipFileURL = try #require(URL(string: "https://example.com/foo.artifacatbundle.zip"))
        let barLatestReleaseURL = try #require(URL(string: "https://api.github.com/repos/foo/bar/releases/latest"))
        let assetResponse = GitHubAssetResponse(
            assets: [GitHubAsset(name: "foo.artifactbundle.zip", browserDownloadURL: zipFileURL)],
            tagName: "0.1.0"
        )
        httpClient.dummyData = try [
            barLatestReleaseURL: JSONEncoder().encode(assetResponse),
            zipFileURL: Data(contentsOf: artifactBundlePath)
        ]

        let controller = NestfileController(
            assetRegistryClientBuilder: AssetRegistryClientBuilder(
                httpClient: httpClient,
                registryConfigs: nil,
                logger: Logger(label: "Test")
            ),
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: httpClient),
            checksumCalculator: SwiftChecksumCalculator(processExecutor: processExecutor)
        )
        let nestfile = Nestfile(nestPath: "./.nest", targets: [
            .repository(Nestfile.Repository(
                reference: "foo/bar",
                version: "0.0.1",
                assetName: nil,
                checksum: nil
            )),
            .zip(Nestfile.ZIPURL(zipURL: zipFileURL.absoluteString, checksum: nil))
        ])
        let newNestfile = try await controller.update(nestfile, excludedVersions: [])
        #expect(newNestfile.nestPath == nestfile.nestPath)
        #expect(newNestfile.targets.count == 2)
        #expect(newNestfile.targets == [
            .repository(Nestfile.Repository(
                reference: "foo/bar",
                version: "0.1.0",
                assetName: "foo.artifactbundle.zip",
                checksum: "aaa"
            )),
            .zip(Nestfile.ZIPURL(zipURL: zipFileURL.absoluteString, checksum: "aaa"))
        ])
    }

    @Test
    func updateWithExcludedVersion() async throws {
        let zipFileURL = try #require(URL(string: "https://example.com/foo.artifacatbundle.zip"))
        let barLatestReleaseURL = try #require(URL(string: "https://api.github.com/repos/foo/bar/releases"))
        let assetResponses = [
            GitHubAssetResponse(
                assets: [GitHubAsset(name: "foo.artifactbundle.zip", browserDownloadURL: zipFileURL)],
                tagName: "0.1.1"
            ),
            GitHubAssetResponse(
                assets: [GitHubAsset(name: "foo.artifactbundle.zip", browserDownloadURL: zipFileURL)],
                tagName: "0.1.0"
            ),
            GitHubAssetResponse(
                assets: [GitHubAsset(name: "foo.artifactbundle.zip", browserDownloadURL: zipFileURL)],
                tagName: "0.0.1"
            )
        ]
        httpClient.dummyData = try [
            barLatestReleaseURL: JSONEncoder().encode(assetResponses),
            zipFileURL: Data(contentsOf: artifactBundlePath)
        ]

        let controller = NestfileController(
            assetRegistryClientBuilder: AssetRegistryClientBuilder(
                httpClient: httpClient,
                registryConfigs: nil,
                logger: Logger(label: "Test")
            ),
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: httpClient),
            checksumCalculator: SwiftChecksumCalculator(processExecutor: processExecutor)
        )
        let nestfile = Nestfile(nestPath: "./.nest", targets: [
            .repository(Nestfile.Repository(
                reference: "foo/bar",
                version: "0.0.1",
                assetName: nil,
                checksum: nil
            )),
            .zip(Nestfile.ZIPURL(zipURL: zipFileURL.absoluteString, checksum: nil))
        ])
        let newNestfile = try await controller.update(nestfile, excludedVersions: [.init(reference: "foo/bar", target: "0.1.1")])
        #expect(newNestfile.nestPath == nestfile.nestPath)
        #expect(newNestfile.targets.count == 2)
        #expect(newNestfile.targets == [
            .repository(Nestfile.Repository(
                reference: "foo/bar",
                version: "0.1.0",
                assetName: "foo.artifactbundle.zip",
                checksum: "aaa"
            )),
            .zip(Nestfile.ZIPURL(zipURL: zipFileURL.absoluteString, checksum: "aaa"))
        ])
    }

    @Test
    func resolve() async throws {
        let zipFileURL = try #require(URL(string: "https://example.com/foo.artifacatbundle.zip"))
        let barReleaseURL = try #require(URL(string: "https://api.github.com/repos/foo/bar/releases/tags/0.0.1"))
        let buzLatestReleaseURL = try #require(URL(string: "https://api.github.com/repos/foo/buz/releases/latest"))
        let barAssetResponse = GitHubAssetResponse(
            assets: [GitHubAsset(name: "foo.artifactbundle.zip", browserDownloadURL: zipFileURL)],
            tagName: "0.0.1"
        )
        let buzAssetResponse = GitHubAssetResponse(
            assets: [GitHubAsset(name: "foo.artifactbundle.zip", browserDownloadURL: zipFileURL)],
            tagName: "0.1.2"
        )
        httpClient.dummyData = try [
            barReleaseURL: JSONEncoder().encode(barAssetResponse),
            zipFileURL: Data(contentsOf: artifactBundlePath),
            buzLatestReleaseURL: JSONEncoder().encode(buzAssetResponse)
        ]

        let controller = NestfileController(
            assetRegistryClientBuilder: AssetRegistryClientBuilder(
                httpClient: httpClient,
                registryConfigs: nil,
                logger: Logger(label: "Test")
            ),
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: httpClient),
            checksumCalculator: SwiftChecksumCalculator(processExecutor: processExecutor)
        )
        let nestfile = Nestfile(nestPath: "./.nest", targets: [
            .repository(Nestfile.Repository(
                reference: "foo/bar",
                version: "0.0.1",
                assetName: nil,
                checksum: nil
            )),
            .repository(Nestfile.Repository(
                reference: "foo/buz",
                version: nil,
                assetName: nil,
                checksum: nil
            )),
        ])
        let newNestfile = try await controller.resolve(nestfile)
        #expect(newNestfile.nestPath == nestfile.nestPath)
        #expect(newNestfile.targets.count == 2)
        #expect(newNestfile.targets == [
            .repository(Nestfile.Repository(
                reference: "foo/bar",
                version: "0.0.1", // Should not be updated in resolve case
                assetName: "foo.artifactbundle.zip",
                checksum: "aaa"
            )),
            .repository(Nestfile.Repository(
                reference: "foo/buz",
                version: "0.1.2",
                assetName: "foo.artifactbundle.zip",
                checksum: "aaa"
            )),
        ])
    }
}
