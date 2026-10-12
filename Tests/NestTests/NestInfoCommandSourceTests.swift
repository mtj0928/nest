import Foundation
import NestKit
import Testing
@testable import nest

struct NestInfoCommandSourceTests {
    @Test(arguments: ["zip", "repositoryAsset", "localBuild", "sshBuild"])
    func formatsStoredSourcesWithoutChangingTheirMetadata(sourceKind: String) throws {
        let zipURL = try #require(URL(string: "https://zip-user:zip-password@downloads.example.com/foo.zip?signature=zip-secret#zip-private"))
        let repositoryURL = try #require(URL(string: "https://repo-user:repo-password@ghe.example.com/owner/repo?token=repo-secret#repo-private"))
        let repository = Repository(reference: .url(repositoryURL), version: "1.0.0")
        let manufacturer: ExecutableManufacturer
        let expectedSource: String
        switch sourceKind {
        case "zip":
            manufacturer = .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: zipURL, repository: nil))
            expectedSource = "https://downloads.example.com/foo.zip"
        case "repositoryAsset":
            manufacturer = .artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: zipURL, repository: repository))
            expectedSource = "https://ghe.example.com/owner/repo"
        case "localBuild":
            manufacturer = .localBuild(repository: repository)
            expectedSource = "https://ghe.example.com/owner/repo"
        case "sshBuild":
            let sshURL = try #require(GitURL.parse(from: "deployment_user@ghe.example.com:owner/repo.git"))
            manufacturer = .localBuild(repository: Repository(reference: sshURL, version: "1.0.0"))
            expectedSource = "ghe.example.com:owner/repo.git"
        default:
            Issue.record("Unexpected source kind")
            return
        }
        let command = NestInfo.Command(version: "1.0.0", binaryPath: "foo", resourcePaths: [], manufacturer: manufacturer)
        let storedInfo = NestInfo(version: NestInfo.currentVersion, commands: ["foo": [command]])
        let storedData = try JSONEncoder().encode(storedInfo)
        let loadedInfo = try JSONDecoder().decode(NestInfo.self, from: storedData)
        let loadedCommand = try #require(loadedInfo.commands["foo"]?.first)

        #expect(loadedCommand.source == expectedSource)
        #expect(loadedInfo == storedInfo)
    }
}
