import Testing
import Foundation
@testable import NestKit

struct ArtifactBundleInfoTests {
    @Test
    func testParseJSON() throws {
        let data = try #require(json.data(using: .utf8))
        let artifactBundle = try JSONDecoder().decode(ArtifactBundleInfo.self, from: data)
        #expect(artifactBundle == ArtifactBundleInfo(schemaVersion: "1.0", artifacts: [
            "swiftlint": Artifact(version: "0.54.0", type: "executable", variants: [
                ArtifactVariant(
                    path: "swiftlint-0.54.0-macos/bin/swiftlint",
                    supportedTriples: ["x86_64-apple-macosx", "arm64-apple-macosx"]
                )
            ])
        ]))
    }
}

private let json = """
{
    "schemaVersion": "1.0",
    "artifacts": {
        "swiftlint": {
            "version": "0.54.0",
            "type": "executable",
            "variants": [
                {
                    "path": "swiftlint-0.54.0-macos/bin/swiftlint",
                    "supportedTriples": ["x86_64-apple-macosx", "arm64-apple-macosx"]
                }
            ]
        }
    }
}
"""
