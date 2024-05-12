import Foundation
import Logging

public struct GitHubRepositoryClient: GitRepositoryClient {
    private let urlSession: URLSession
    private let logger: Logger

    public init(urlSession: URLSession, logger: Logger) {
        self.urlSession = urlSession
        self.logger = logger
    }

    public func fetchAssets(repositoryURL: URL, version: GitVersion) async throws -> AssetInformation {
        let assetURL = try GitHubURLBuilder.assetURL(repositoryURL, version: version)
        var urlRequest = URLRequest(url: assetURL)
        urlRequest.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, urlResponse) = try await urlSession.data(for: urlRequest)
        if (urlResponse as? HTTPURLResponse)?.statusCode == 404 {
            throw GitRepositoryClientError.notFound
        }
        let response = try JSONDecoder().decode(GitHubAssetResponse.self, from: data)
        let assets = response.assets.map { asset in
            Asset(fileName: asset.name, url: asset.browserDownloadURL)
        }
        return AssetInformation(tagName: response.tagName, assets: assets)
    }
}
