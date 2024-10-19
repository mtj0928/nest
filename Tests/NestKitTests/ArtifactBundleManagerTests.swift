import Foundation
import Testing
@testable import NestKit
import NestTestHelpers

struct ArtifactBundleManagerTests {
    let nestDirectory = NestDirectory(rootDirectory: URL(filePath: "/User/.nest"))
    let fileSystem = MockFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/User"),
        temporaryDirectory: URL(filePath: "/User/temp")
    )

    @Test
    func install() async throws {
        let binaryData = "binaryData".data(using: .utf8)!
        fileSystem.item = [
            "/": [
                "User": [
                    "Desktop": ["binary": .file(data: binaryData)]
                ]
            ]
        ]
        let manager = ArtifactBundleManager(fileSystem: fileSystem, directory: nestDirectory)
        let manufacturer = ExecutableManufacturer.localBuild(
            repository: .init(reference: .url(URL(string: "https://github.com/aaa/bbb")!), version: "1.0.0")
        )
        let binary = ExecutableBinary(
            commandName: "foo",
            binaryPath: URL(filePath: "/User/Desktop/binary"),
            version: "1.0.0",
            manufacturer: manufacturer
        )
        try manager.install(binary)

        let binaryInArtifactBundlePath = "/User/.nest/artifacts/aaa_bbb_github.com_https/1.0.0/local_build/foo"
        let binaryInArtifactBundle = try fileSystem.data(at: URL(filePath: binaryInArtifactBundlePath))
        #expect(binaryInArtifactBundle == binaryData)

        let binaryInBin = try fileSystem.data(at: URL(filePath: "/User/.nest/bin/foo"))
        #expect(binaryInBin == binaryData)

        let nestInfo = manager.nestInfoController.getInfo()
        #expect(nestInfo.commands["foo"] == [NestInfo.Command(
            version: "1.0.0",
            binaryPath: "/artifacts/aaa_bbb_github.com_https/1.0.0/local_build/foo",
            resourcePaths: [],
            manufacturer: manufacturer
        )])
    }

    @Test
    func uninstall() async throws {
        let binaryData = "binaryData".data(using: .utf8)!
        fileSystem.item = [
            "/": [
                "User": [
                    "Desktop": ["binary": .file(data: binaryData)]
                ]
            ]
        ]
        let manager = ArtifactBundleManager(fileSystem: fileSystem, directory: nestDirectory)
        let binary = ExecutableBinary(
            commandName: "foo",
            binaryPath: URL(filePath: "/User/Desktop/binary"),
            version: "1.0.0",
            manufacturer: .localBuild(
                repository: .init(reference: .url(URL(string: "https://github.com/aaa/bbb")!), version: "1.0.0")
            )
        )
        try manager.install(binary)
        try manager.uninstall(command: "foo", version: "1.0.0")

        let binaryInArtifactBundlePath = "/User/.nest/artifacts/aaa_bbb_github.com_https/1.0.0/local_build/foo"
        let binaryInArtifactBundle = try? fileSystem.data(at: URL(filePath: binaryInArtifactBundlePath))
        #expect(binaryInArtifactBundle == nil)

        let symbolicatedBinary = try? fileSystem.data(at: URL(filePath: "/User/.nest/bin/foo"))
        #expect(symbolicatedBinary == nil)

        let nestInfo = manager.nestInfoController.getInfo()
        #expect(nestInfo.commands.isEmpty)
    }

    @Test
    func list() async throws {
        let binaryData = "binaryData".data(using: .utf8)!
        fileSystem.item = [
            "/": [
                "User": [
                    "Desktop": ["binary": .file(data: binaryData)]
                ]
            ]
        ]
        let manager = ArtifactBundleManager(fileSystem: fileSystem, directory: nestDirectory)
        let binaryA = ExecutableBinary(
            commandName: "foo",
            binaryPath: URL(filePath: "/User/Desktop/binary"),
            version: "1.0.0",
            manufacturer: .localBuild(
                repository: .init(reference: .url(URL(string: "https://github.com/aaa/bbb")!), version: "1.0.0")
            )
        )
        let binaryB = ExecutableBinary(
            commandName: "foo",
            binaryPath: URL(filePath: "/User/Desktop/binary"),
            version: "1.0.1",
            manufacturer: .localBuild(
                repository: .init(reference: .url(URL(string: "https://github.com/aaa/bbb")!), version: "1.0.1")
            )
        )
        try manager.install(binaryA)
        try manager.install(binaryB)
        let list = manager.list()
        #expect(Set(list["foo"] ?? []) == [
            NestInfo.Command(
                version: "1.0.0",
                binaryPath: "/artifacts/aaa_bbb_github.com_https/1.0.0/local_build/foo",
                resourcePaths: [],
                manufacturer: .localBuild(
                    repository: .init(reference: .url(URL(string: "https://github.com/aaa/bbb")!), version: "1.0.0")
                )
            ),
            NestInfo.Command(
                version: "1.0.1",
                binaryPath: "/artifacts/aaa_bbb_github.com_https/1.0.1/local_build/foo",
                resourcePaths: [],
                manufacturer: .localBuild(
                    repository: .init(reference: .url(URL(string: "https://github.com/aaa/bbb")!), version: "1.0.1")
                )
            )
        ])
    }
}
