import Foundation
import Testing
import NestCLI
import NestTestHelpers

struct NestfileTests {
    let fileSystem = MockFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/User"),
        temporaryDirectory: URL(filePath: "/tmp")
    )

    @Test
    func loadFile() async throws {
        let nestFile = """
        nestPath: "aaa"
        targets:
          - reference: mtj0928/nest
            version: 0.1.0
            assetName: nest-macos.artifactbundle.zip
          - https://github.com/mtj0928/nest/releases/download/0.1.0/nest-macos.artifactbundle.zip
        """

        fileSystem.item = [
            "/": [
                "User" : .directory,
                "tmp": .directory
            ]
        ]
        let nestFilePath = URL(filePath: "/User/nestfile")
        try fileSystem.write(nestFile.data(using: .utf8)!, to: nestFilePath)
        let nest = try Nestfile.load(from: nestFilePath.path(), fileSystem: fileSystem)
        #expect(nest.nestPath == "aaa")
        #expect(nest.targets[0] == .repository(Nestfile.Repository(
            reference: "mtj0928/nest",
            version: "0.1.0",
            assetName: "nest-macos.artifactbundle.zip",
            checksum: nil
        )))
        #expect(nest.targets[1] == .deprecatedZIP(Nestfile.DeprecatedZIPURL(
            url: "https://github.com/mtj0928/nest/releases/download/0.1.0/nest-macos.artifactbundle.zip"
        )))
        #expect(nest.registries == nil)
    }

    @Test
    func loadFileWithServers() async throws {
        let nestFile = """
        nestPath: "aaa"
        targets:
          - reference: mtj0928/nest
            version: 0.1.0
            assetName: nest-macos.artifactbundle.zip
          - https://github.com/mtj0928/nest/releases/download/0.1.0/nest-macos.artifactbundle.zip
        registries:
          github:
            - host: github.com
              tokenEnvironmentVariable: "GH_TOKEN"
            - host: my-ghe.example.com
              tokenEnvironmentVariable: "MY_GHE_TOKEN"
        """

        fileSystem.item = [
            "/": [
                "User" : .directory,
                "tmp": .directory
            ]
        ]
        let nestFilePath = URL(filePath: "/User/nestfile")
        try fileSystem.write(nestFile.data(using: .utf8)!, to: nestFilePath)
        let nest = try Nestfile.load(from: nestFilePath.path(), fileSystem: fileSystem)
        #expect(nest.nestPath == "aaa")
        #expect(nest.targets[0] == .repository(Nestfile.Repository(
            reference: "mtj0928/nest",
            version: "0.1.0",
            assetName: "nest-macos.artifactbundle.zip",
            checksum: nil
        )))
        #expect(nest.targets[1] == .deprecatedZIP(Nestfile.DeprecatedZIPURL(
            url: "https://github.com/mtj0928/nest/releases/download/0.1.0/nest-macos.artifactbundle.zip"
        )))
        let githubInfo = try #require(nest.registries?.github)
        #expect(githubInfo.count == 2)

        let githubServer = try #require(githubInfo.first { $0.host == "github.com" })
        #expect(githubServer.tokenEnvironmentVariable == "GH_TOKEN")

        let gheServer = try #require(githubInfo.first { $0.host == "my-ghe.example.com" })
        #expect(gheServer.tokenEnvironmentVariable == "MY_GHE_TOKEN")
    }
}
