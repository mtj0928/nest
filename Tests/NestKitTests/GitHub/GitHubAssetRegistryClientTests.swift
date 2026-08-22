import Foundation
import HTTPTypes
import Logging
import NestTestHelpers
import os
import Testing
@testable import NestKit

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
            registryConfigs: nil,
            logger: .init(label: "Test")
        )
        let assets = try await gitHubAssetRegistryClient.fetchAssets(repositoryURL: repositoryURL, version: .tag("1.2.3"))
        #expect(assets.assets == [Asset(fileName: "foo.zip", url: assetURL)])
    }

    @Test(arguments: [
        ("https://github.com/owner/repo", "github-com-token"),
        ("https://known-server.example.com/owner/repo", "known-token"),
        ("https://other-server.example.com/owner/repo", "other-token"),
        ("https://ghe-token-server.example.com/owner/repo", "explicit-enterprise-token"),
        ("https://gh-token-misconfigured.example.com/owner/repo", nil),
        ("https://attacker.example/owner/repo", nil),
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
            "GH_TOKEN": "github-com-token",
            "GHE_TOKEN": "explicit-enterprise-token",
            "KNOWN_SERVER_TOKEN": "known-token",
            "OTHER_SERVER_TOKEN": "other-token"
        ])
        let registryConfigs = GitHubRegistryConfigs.resolve(
            environmentVariableNames: [
                "known-server.example.com": "KNOWN_SERVER_TOKEN",
                "other-server.example.com": "OTHER_SERVER_TOKEN",
                "ghe-token-server.example.com": "GHE_TOKEN",
                "gh-token-misconfigured.example.com": "GH_TOKEN"
            ],
            environmentVariablesStorage: environmentVariables
        )
        let githubRegistryClient: AssetRegistryClient = GitHubAssetRegistryClient(
            httpClient: httpClient,
            registryConfigs: registryConfigs,
            logger: .init(label: "Test")
        )
        let _ = try await githubRegistryClient.fetchAssets(repositoryURL: repositoryURL, version: .tag("1.2.3"))
    }

    @Test
    func rejectsHTTPEnterpriseURLBeforeNetworkAccess() async throws {
        let repositoryURL = try #require(URL(string: "http://ghe.example.com/owner/repo"))
        let didAccessNetwork = OSAllocatedUnfairLock(initialState: false)
        let httpClient = GitHubMockHTTPClient(fileSystem: fileSystem) { _ in
            didAccessNetwork.withLock { $0 = true }
            return (Data(), HTTPResponse(status: .ok))
        }
        let client = GitHubAssetRegistryClient(
            httpClient: httpClient,
            registryConfigs: GitHubRegistryConfigs.resolve(environmentVariableNames: [:]),
            logger: Logger(label: "Test")
        )

        await #expect(throws: GitHubURLBuilder.InvalidURLError.self) {
            try await client.fetchAssets(repositoryURL: repositoryURL, version: .latestRelease)
        }
        #expect(!didAccessNetwork.withLock { $0 })
    }

    @Test
    func verboseLogsRedactRequestTokenAndDoNotLogResponseBody() async throws {
        let token = "bearer-token-that-must-never-be-logged"
        let signedURL = "https://downloads.example.com/foo.zip?signature=\(token)"
        let repositoryURL = try #require(URL(string: "https://github.com/owner/repo"))
        let httpClient = GitHubMockHTTPClient(fileSystem: fileSystem) { request in
            #expect(request.headerFields[.authorization] == "Bearer \(token)")
            let json = """
            {
                "tag_name": "1.2.3",
                "assets": [
                    {
                        "name": "foo.zip",
                        "browser_download_url": "\(signedURL)"
                    }
                ]
            }
            """
            return (json.data(using: .utf8)!, HTTPResponse(status: .ok))
        }
        let registryConfigs = GitHubRegistryConfigs.resolve(
            environmentVariableNames: [:],
            environmentVariablesStorage: TestingEnvironmentVariables(environmentVariables: ["GH_TOKEN": token])
        )
        let logRecorder = TestLogRecorder()
        let client = GitHubAssetRegistryClient(
            httpClient: httpClient,
            registryConfigs: registryConfigs,
            logger: logRecorder.makeLogger(logLevel: .trace)
        )

        _ = try await client.fetchAssets(repositoryURL: repositoryURL, version: .tag("1.2.3"))

        let logs = logRecorder.messages.joined(separator: "\n")
        #expect(!logs.contains(token))
        #expect(!logs.contains("signature="))
        #expect(logs.contains("Authorization: <redacted>"))
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
