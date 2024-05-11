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

        #expect(nestDirectory.repository(gitURL: .url(URL(string: "https://github.com/xxx/yyy")!)).relativePath == ".nest/artifacts/xxx_yyy")
    }
}
