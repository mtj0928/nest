import Testing
import Foundation
@testable import NestKit
import NestTestHelpers

struct SwiftPackageTests {

    @Test
    func executableFile() async throws {
        let swiftPackage = SwiftPackage(
            at: URL(filePath: "/User"),
            executorBuilder: MockExecutorBuilder { command, arguments in
                ""
            }
        )
        let executableFilePath = swiftPackage.executableFile(name: "foo")
        #expect(executableFilePath.path() == "/User/.build/release/foo")
    }

    @Test
    func buildForRelease() async throws {
        let swiftPackage = SwiftPackage(
            at: URL(filePath: "/User"),
            executorBuilder: MockExecutorBuilder(dummy: [
                "/usr/bin/which swift": "/usr/bin/swift",
                "/usr/bin/swift build -c release": "success"
            ])
        )
        try await swiftPackage.buildForRelease()
    }

    @Test
    func description() async throws {
        let swiftPackage = SwiftPackage(
            at: URL(filePath: "/User"),
            executorBuilder: MockExecutorBuilder(dummy: [
                "/usr/bin/which swift": "/usr/bin/swift",
                "/usr/bin/swift package describe --type json": """
                {
                    "products": [
                        {
                            "name": "foo",
                            "type": {
                                "executable" : null
                            }
                        },
                        {
                            "name": "bar",
                            "type" : {
                                "library" : [
                                    "automatic"
                                ]
                            }
                        },
                    ]
                }
                """
            ])
        )
        let packageDescription = try await swiftPackage.description()
        #expect(packageDescription.executableNames == ["foo"])
        #expect(packageDescription.products == [
            SwiftPackageDescription.Product(name: "foo", type: .executable),
            SwiftPackageDescription.Product(name: "bar", type: .library(.automatic))
        ])
    }
}
