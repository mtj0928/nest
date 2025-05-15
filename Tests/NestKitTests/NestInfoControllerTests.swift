import Foundation
@testable import NestKit
import Testing
import NestTestHelpers

struct NestInfoControllerTests {
    let nestDirectory = NestDirectory(rootDirectory: URL(filePath: "/User/.nest"))
    let mockFileSystem = MockFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/User"),
        temporaryDirectory: URL(filePath: "/tmp")
    )

    init() {
        mockFileSystem.item = [
            "/": [
                "User": [
                    ".nest": [:]
                ]
            ]
        ]
    }
    
    @Test
    func fetch() throws {
        let nestInfoController = NestInfoController(directory: nestDirectory, fileSystem: mockFileSystem)
        let commands = [
            try NestInfo.Command(
                version: "0.0.1",
                binaryPath: "a",
                resourcePaths: ["b", "c"],
                manufacturer: .artifactBundle(
                    sourceInfo: ArtifactBundleSourceInfo(
                        zipURL: #require(URL(string: "https://foo.com/bar.zip")),
                        repository: Repository(
                            reference: #require(.parse(string: "owner/foo")),
                            version: "0.0.1"
                        )
                    )
                )
            ),
            try NestInfo.Command(
                version: "0.0.2",
                binaryPath: "a",
                resourcePaths: ["b", "c"],
                manufacturer: .artifactBundle(
                    sourceInfo: ArtifactBundleSourceInfo(
                        zipURL: #require(URL(string: "https://foo.com/bar.zip")),
                        repository: Repository(
                            reference: #require(.parse(string: "owner/foo")),
                            version: "0.0.2"
                        )
                    )
                )
            )
        ]
        for command in commands {
            try nestInfoController.add(name: "foo", command: command)
        }
        #expect(try nestInfoController.fetchCommand(reference: "owner/foo", version: "0.0.2") == commands[1])
        #expect(try nestInfoController.fetchCommand(reference: "owner/foo", version: "0.0.3") == nil)
    }

    @Test
    func add() throws {
        let nestInfoController = NestInfoController(directory: nestDirectory, fileSystem: mockFileSystem)
        let command = try NestInfo.Command(
            version: "0.0.1",
            binaryPath: "a",
            resourcePaths: ["b", "c"],
            manufacturer: .artifactBundle(
                sourceInfo: ArtifactBundleSourceInfo(
                    zipURL: #require(URL(string: "https://foo.com/bar.zip")),
                    repository: Repository(
                        reference: #require(.parse(string: "foo/bar")),
                        version: "0.0.1"
                    )
                )
            )
        )
        try nestInfoController.add(name: "foo", command: command)
        #expect(nestInfoController.getInfo() == NestInfo(version: "1", commands: ["foo": [command]]))
    }

    @Test
    func remove() throws {
        let nestInfoController = NestInfoController(directory: nestDirectory, fileSystem: mockFileSystem)
        let command = try NestInfo.Command(
            version: "0.0.1",
            binaryPath: "a",
            resourcePaths: ["b", "c"],
            manufacturer: .artifactBundle(
                sourceInfo: ArtifactBundleSourceInfo(
                    zipURL: #require(URL(string: "https://foo.com/bar.zip")),
                    repository: Repository(
                        reference: #require(.parse(string: "foo/bar")),
                        version: "0.0.1"
                    )
                )
            )
        )
        try nestInfoController.add(name: "foo", command: command)
        #expect(nestInfoController.getInfo() == NestInfo(version: "1", commands: ["foo": [command]]))

        try nestInfoController.remove(command: "bar", version: "0.0.1")
        try nestInfoController.remove(command: "foo", version: "1.2.1")
        #expect(nestInfoController.getInfo() == NestInfo(version: "1", commands: ["foo": [command]]))

        try nestInfoController.remove(command: "foo", version: "0.0.1")
        #expect(nestInfoController.getInfo() == NestInfo(version: "1", commands: [:]))
    }
}

