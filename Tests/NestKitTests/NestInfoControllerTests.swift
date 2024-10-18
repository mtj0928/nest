import Foundation
@testable import NestKit
import Testing

struct NestInfoControllerTests {
    let nestDirectory = NestDirectory(rootDirectory: URL(filePath: "/User/.nest"))
    let mockFileStorage = MockFileStorage(
        homeDirectoryForCurrentUser: URL(filePath: "/User"),
        temporaryDirectory: URL(filePath: "/tmp")
    )

    init() {
        mockFileStorage.item = [
            "/": [
                "User": [
                    ".nest": [:]
                ]
            ]
        ]
    }

    @Test
    func add() throws {
        let nestInfoController = NestInfoController(directory: nestDirectory, fileStorage: mockFileStorage)
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
        let nestInfoController = NestInfoController(directory: nestDirectory, fileStorage: mockFileStorage)
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

