import Foundation
import HTTPTypes
import HTTPTypesFoundation
import Logging

public struct GitHubRepositoryClient: AssetRegistryClient {
    private let httpClient: any HTTPClient
    private let authToken: String?
    private let logger: Logger

    public init(httpClient: some HTTPClient, authToken: String?, logger: Logger) {
        self.httpClient = httpClient
        self.authToken = authToken
        self.logger = logger
    }

    public func fetchAssets(repositoryURL: URL, version: GitVersion) async throws -> AssetInformation {
        let assetURL = try GitHubURLBuilder.assetURL(repositoryURL, version: version)
        var request = HTTPRequest(url: assetURL)
        request.headerFields = [
            .accept: "application/vnd.github+json",
            .gitHubAPIVersion: "2022-11-28",
        ]
        if let authToken {
            request.headerFields[.authorization] = "Bearer \(authToken)"
        }

        logger.debug("Request: \(repositoryURL)")
        logger.debug("Request: \(request.headerFields)")
        let (data, response) = try await httpClient.data(for: request)
        logger.debug("Response: \(data.humanReadableJSONString() ?? "No data")")
        logger.debug("Status: \(response.status)")

        if response.status == .notFound {
            throw AssetRegistryClientError.notFound
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

extension Data {
    fileprivate func humanReadableJSONString() -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: self, options: []),
              let prettyPrintedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
        else { return nil }
        return String(data: prettyPrintedData, encoding: .utf8)
    }
}
