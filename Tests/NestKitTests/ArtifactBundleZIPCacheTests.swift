import Foundation
import Testing
@testable import NestKit

struct ArtifactBundleZIPCacheTests {
    private let directory = URL(filePath: "/User/Library/Caches/nest/artifact-bundle-zips")

    @Test
    func cacheFileURLStaysWithinCacheDirectory() throws {
        let cache = ArtifactBundleZIPCache(directory: directory)
        let remoteURL = try #require(URL(string: "https://example.com/%2E%2E/%2E%2E/%2E%2E/%2E%2E/archive.zip"))

        let cacheFileURL = cache.fileURL(for: remoteURL)
        let actualPathComponents = cacheFileURL.standardizedFileURL.pathComponents
        let cacheDirectoryPathComponents = directory.standardizedFileURL.pathComponents

        #expect(actualPathComponents.starts(with: cacheDirectoryPathComponents))
        #expect(!actualPathComponents.dropFirst(cacheDirectoryPathComponents.count).contains(".."))
        #expect(cacheFileURL.pathExtension == "zip")
    }

    @Test
    func cacheFileURLPreservesReadableOrigin() throws {
        let cache = ArtifactBundleZIPCache(directory: directory)
        let remoteURLString = """
            https://github.com/realm/SwiftLint/releases/download/1.0.0/\
            SwiftLintBinary-macos.artifactbundle.zip
            """
        let remoteURL = try #require(URL(string: remoteURLString))

        let cacheFileURL = cache.fileURL(for: remoteURL)
        let relativePathComponents = cacheFileURL.pathComponents.dropFirst(directory.pathComponents.count)

        #expect(Array(relativePathComponents.dropLast()) == [
            "https",
            "github.com",
            "realm",
            "SwiftLint",
            "releases",
            "download",
            "1.0.0"
        ])
        #expect(relativePathComponents.last?.hasPrefix("SwiftLintBinary-macos.artifactbundle-") == true)
    }

    @Test(arguments: [
        ("https://example.com/archive.zip?version=1", "https://example.com/archive.zip?version=2"),
        ("https://example.com:443/archive.zip", "https://example.com:8443/archive.zip")
    ])
    func distinctRemoteURLsUseDistinctCacheFiles(firstURLString: String, secondURLString: String) throws {
        let cache = ArtifactBundleZIPCache(directory: directory)
        let firstURL = try #require(URL(string: firstURLString))
        let secondURL = try #require(URL(string: secondURLString))

        #expect(cache.fileURL(for: firstURL) != cache.fileURL(for: secondURL))
    }

    @Test
    func fragmentDoesNotAffectCacheIdentity() throws {
        let cache = ArtifactBundleZIPCache(directory: directory)
        let firstURL = try #require(URL(string: "https://example.com/archive.zip#first"))
        let secondURL = try #require(URL(string: "https://example.com/archive.zip#second"))

        #expect(cache.fileURL(for: firstURL) == cache.fileURL(for: secondURL))
    }
}
