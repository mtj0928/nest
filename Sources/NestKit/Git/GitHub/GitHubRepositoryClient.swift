import Foundation

public struct GitHubRepositoryClient: GitRepositoryClient {
    private let urlSession: URLSession

    public init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    public func fetchAssets(repositoryURL: URL, tag: String) async throws -> AssetInformation {
        let assetURL = try GitHubURLBuilder.assetURL(repositoryURL, tag: tag)
        var urlRequest = URLRequest(url: assetURL)
        urlRequest.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, urlResponse) = try await urlSession.data(for: urlRequest)
        if (urlResponse as? HTTPURLResponse)?.statusCode == 404 {
            throw GitHubRepositoryClientError(errorDescription: "Not found for \(repositoryURL) (\(tag))")
        }
        let response = try JSONDecoder().decode(GitHubAssetResponse.self, from: data)
        let assets = response.assets.map { asset in
            Asset(fileName: asset.name, url: asset.browserDownloadURL)
        }
        return AssetInformation(tagName: response.tagName, assets: assets)
    }
}

struct GitHubRepositoryClientError: LocalizedError {
    let errorDescription: String?
}
