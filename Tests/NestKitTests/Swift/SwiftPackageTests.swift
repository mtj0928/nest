import Testing
import Foundation
@testable import NestKit

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

struct MockExecutorBuilder: ProcessExecutorBuilder {
    let executorClosure: @Sendable (String, [String]) async throws -> String

    init(executorClosure: @escaping @Sendable (String, [String]) -> String) {
        self.executorClosure = executorClosure
    }

    init(dummy: [String: String]) {
        self.executorClosure = { command, arguments in
            let command = ([command] + arguments).joined(separator: " ")
            guard let result = dummy[command] else {
                Issue.record("Unexpected commend: \(command)")
                return ""
            }
            return result
        }
    }

    func build(currentDirectory: URL?) -> any NestKit.ProcessExecutor {
        MockProcessExecutor(executorClosure: executorClosure)
    }
}

struct MockProcessExecutor: ProcessExecutor {
    let executorClosure: @Sendable (String, [String]) async throws -> String

    init(executorClosure: @escaping @Sendable (String, [String]) async throws -> String) {
        self.executorClosure = executorClosure
    }

    init(dummy: [String: String]) {
        self.executorClosure = { command, arguments in
            let command = ([command] + arguments).joined(separator: " ")
            guard let result = dummy[command] else {
                Issue.record("Unexpected commend: \(command)")
                return ""
            }
            return result
        }
    }

    func execute(command: String, _ arguments: [String]) async throws -> String {
        try await executorClosure(command, arguments)
    }
}
