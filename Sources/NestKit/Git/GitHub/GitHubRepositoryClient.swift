import Foundation
import HTTPTypes
import HTTPTypesFoundation
import Logging

public struct GitHubRepositoryClient: GitRepositoryClient {
    private let httpClient: any HTTPClient
    private let logger: Logger

    public init(httpClient: some HTTPClient, logger: Logger) {
        self.httpClient = httpClient
        self.logger = logger
    }

    public func fetchAssets(repositoryURL: URL, version: GitVersion) async throws -> AssetInformation {
        let assetURL = try GitHubURLBuilder.assetURL(repositoryURL, version: version)
        var request = HTTPRequest(url: assetURL)
        request.headerFields = [
            .accept: "application/vnd.github+json",
            .gitHubAPIVersion: "2022-11-28"
        ]
        let (data, response) = try await httpClient.data(for: request)
        if response.status == .notFound {
            throw GitRepositoryClientError.notFound
        }
        let assetResponse = try JSONDecoder().decode(GitHubAssetResponse.self, from: data)
        let assets = assetResponse.assets.map { asset in
            Asset(fileName: asset.name, url: asset.browserDownloadURL)
        }
        return AssetInformation(tagName: assetResponse.tagName, assets: assets)
    }
}

extension HTTPField.Name {
    static let gitHubAPIVersion = HTTPField.Name("X-GitHub-Api-Version")!
}
