import Foundation
import Testing
@testable import NestKit

struct NestDirectoryTests {
    @Test
    func testNestDirectory() throws {
        let rootDirectory = URL(fileURLWithPath: ".nest")
        let nestDirectory = NestDirectory(rootDirectory: rootDirectory)

        #expect(nestDirectory.bin.relativeString == ".nest/bin")
        #expect(nestDirectory.artifacts.relativeString == ".nest/artifacts")

        #expect(
            nestDirectory.source(
                .artifactBundle(
                    sourceInfo: ArtifactBundleSourceInfo(
                        zipURL: URL(string: "https://example.com/xxx/yyy.zip")!,
                        repository: Repository(
                            reference: .url(URL(string: "https://github.com/xxx/yyy")!),
                            version: "0"
                        )
                    )
                )
            ).relativePath == ".nest/artifacts/xxx_yyy_github.com_https"
        )
        #expect(
            nestDirectory.source(
                .artifactBundle(
                    sourceInfo: ArtifactBundleSourceInfo(
                        zipURL: URL(string: "https://example.com/xxx/yyy.zip")!,
                        repository: nil
                    )
                )
            ).relativePath == ".nest/artifacts/xxx_yyy.zip_example.com_https"
        )
        #expect(
            nestDirectory.source(
                .localBuild(repository: Repository(
                    reference: .url(URL(string: "https://github.com/xxx/yyy")!),
                    version: "0"
                ))
            ).relativePath == ".nest/artifacts/xxx_yyy_github.com_https"
        )
    }
}
