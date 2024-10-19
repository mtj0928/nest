import NestKit
import Testing
import Foundation
import NestTestHelpers

struct TripleDetectorTests {
    @Test
    func detect() async throws {
        let swiftCommand = SwiftCommand(executor: MockProcessExecutor(dummy: [
            "/usr/bin/which swift": "/usr/bin/swift",
            "/usr/bin/swift -print-target-info": """
            {
                "target": {
                    "unversionedTriple": "arm64-apple-macosx",
                }
            }
            """
        ]))
        let detector = TripleDetector(swiftCommand: swiftCommand)
        #expect(try await detector.detect() == "arm64-apple-macosx")
    }
}
