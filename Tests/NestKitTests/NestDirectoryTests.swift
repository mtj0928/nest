import Foundation
import Testing
@testable import NestKit

struct NestDirectoryTests {
    let nestDirectory = NestDirectory(rootDirectory: URL(fileURLWithPath: ".nest"))

    @Test
    func nestDirectory() async throws {
        #expect(nestDirectory.infoJSON.relativeString == ".nest/info.json")
        #expect(nestDirectory.bin.relativeString == ".nest/bin")
        #expect(nestDirectory.artifacts.relativeString == ".nest/artifacts")
    }

    @Test
    func artifactsURLForArtifactBundleInRepository() throws {
        let artifactBundle = try ExecutableManufacturer.artifactBundle(
            sourceInfo: ArtifactBundleSourceInfo(
                zipURL: #require(URL(string: "https://example.com/foo/bar.zip")),
                repository: Repository(
                    reference: .url(#require(URL(string: "https://github.com/owner/name"))),
                    version: "0"
                )
            )
        )
        #expect(nestDirectory.source(artifactBundle).relativePath == ".nest/artifacts/owner_name_github.com_https")

        let binaryDirectory = nestDirectory.binaryDirectory(manufacturer: artifactBundle, version: "0")
        #expect(binaryDirectory.relativePath == ".nest/artifacts/owner_name_github.com_https/0/bar")
    }

    @Test
    func artifactsURLForZIPURL() throws {
        let artifactBundle = try ExecutableManufacturer.artifactBundle(
            sourceInfo: ArtifactBundleSourceInfo(
                zipURL: #require(URL(string: "https://example.com/foo/bar.zip")),
                repository: nil
            )
        )
        #expect(nestDirectory.source(artifactBundle).relativePath == ".nest/artifacts/foo_bar.zip_example.com_https")
        let binaryDirectory = nestDirectory.binaryDirectory(manufacturer: artifactBundle, version: "0")
        #expect(binaryDirectory.relativePath == ".nest/artifacts/foo_bar.zip_example.com_https/0/bar")
    }

    @Test
    func artifactsURLForLocalBuild() throws {
        let artifactBundle = try ExecutableManufacturer.localBuild(repository: Repository(
            reference:  .url(#require(URL(string: "https://github.com/xxx/yyy"))),
            version: "0"
        ))
        #expect(nestDirectory.source(artifactBundle).relativePath == ".nest/artifacts/xxx_yyy_github.com_https")
        let binaryDirectory = nestDirectory.binaryDirectory(manufacturer: artifactBundle, version: "0")
        #expect(binaryDirectory.relativePath == ".nest/artifacts/xxx_yyy_github.com_https/0/local_build")
    }

    @Test
    func version() throws {
        let artifactBundle = try ExecutableManufacturer.localBuild(repository: Repository(
            reference:  .url(#require(URL(string: "https://github.com/xxx/yyy"))),
            version: "0"
        ))
        let result = nestDirectory.version(manufacturer: artifactBundle, version: "0.0.1")
        #expect(result.relativePath == ".nest/artifacts/xxx_yyy_github.com_https/0.0.1")
    }

    @Test
    func url() {
        #expect(nestDirectory.url("foo/bar").relativePath == ".nest/foo/bar")
    }

    @Test
    func symbolicPath() {
        #expect(nestDirectory.symbolicPath(name: "foo").relativePath == ".nest/bin/foo")
    }
}
