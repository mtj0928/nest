@testable import NestKit
import NestTestHelpers
import Foundation
import HTTPTypes
import Testing

struct GitHubAssetRegistryClientTests {
    let fileSystem = MockFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/User"),
        temporaryDirectory: URL(filePath: "/tmp")
    )

    @Test func fetchAssets() async throws {
        let repositoryURL = try #require(URL(string: "https://github.com/owner/repo"))
        let assetURL = try #require(URL(string: "https://example.com/foo.zip"))
        let httpClient = GitHubMockHTTPClient(fileSystem: fileSystem) { request in
            #expect(request.method == .get)
            #expect(request.url?.absoluteString == "https://api.github.com/repos/owner/repo/releases/tags/1.2.3")
            #expect(request.headerFields == [
                .accept: "application/vnd.github+json",
                .gitHubAPIVersion: "2022-11-28"
            ])
            let json = """
            {
                "tag_name": "1.2.3",
                "assets": [
                    {
                        "name": "foo.zip",
                        "browser_download_url": "\(assetURL.absoluteString)"
                    }
                ]
            }
            """
            return (json.data(using: .utf8)!, HTTPResponse(status: .ok))
        }
        let gitHubAssetRegistryClient = GitHubAssetRegistryClient(
            httpClient: httpClient,
            serverConfigs: nil,
            logger: .init(label: "Test")
        )
        let assets = try await gitHubAssetRegistryClient.fetchAssets(repositoryURL: repositoryURL, version: .tag("1.2.3"))
        #expect(assets.assets == [Asset(fileName: "foo.zip", url: assetURL)])
    }

    @Test(arguments: [
        ("https://github.com/owner/repo", "github-com-token"),
        ("https://known-server.example.com/owner/repo", "known-token"),
        ("https://unknown-server.example.com/owner/repo", nil),
    ])
    func fetchAssetsCanReceiveValidAuthorization(repositoryURLString: String, expectedAuthorization: String?) async throws {
        let repositoryURL = try #require(URL(string: repositoryURLString))
        let assetURL = try #require(URL(string: "https://example.com/foo.zip"))
        let httpClient = GitHubMockHTTPClient(fileSystem: fileSystem) { request in
            if let expectedAuthorization {
                #expect(request.headerFields[.authorization] == "Bearer \(expectedAuthorization)")
            } else {
                #expect(request.headerFields[.authorization] == nil)
            }
            let json = """
            {
                "tag_name": "1.2.3",
                "assets": [
                    {
                        "name": "foo.zip",
                        "browser_download_url": "\(assetURL.absoluteString)"
                    }
                ]
            }
            """
            return (json.data(using: .utf8)!, HTTPResponse(status: .ok))
        }
        let environmentVariables = TestingEnvironmentVariables(environmentVariables: [
            "GITHUB_COM_TOKEN": "github-com-token",
            "KNOWN_SERVER_TOKEN": "known-token",
        ])
        let serverConfigs = GitHubServerConfigs.resolve(
            environmentVariableNames: [
                "github.com": "GITHUB_COM_TOKEN",
                "known-server.example.com": "KNOWN_SERVER_TOKEN",
            ],
            environmentVariablesStorage: environmentVariables
        )
        let githubRegistryClient: AssetRegistryClient = GitHubAssetRegistryClient(
            httpClient: httpClient,
            serverConfigs: serverConfigs,
            logger: .init(label: "Test")
        )
        let _ = try await githubRegistryClient.fetchAssets(repositoryURL: repositoryURL, version: .tag("1.2.3"))
    }
}

struct GitHubMockHTTPClient: HTTPClient {
    let fileSystem: MockFileSystem
    let dataHandler: @Sendable (HTTPRequest) async throws -> (Data, HTTPResponse)

    init(fileSystem: MockFileSystem, dataHandler: @escaping @Sendable (HTTPRequest) -> (Data, HTTPResponse)) {
        self.fileSystem = fileSystem
        self.dataHandler = dataHandler
    }

    func data(for request: HTTPRequest) async throws -> (Data, HTTPResponse) {
        try await dataHandler(request)
    }
    
    func download(for request: HTTPRequest) async throws -> (URL, HTTPResponse) {
        let (data, response) = try await data(for: request)
        let fileURL = fileSystem.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileSystem.write(data, to: fileURL)
        return (fileURL, response)
    }
}
