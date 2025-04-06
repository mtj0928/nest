import Foundation
import HTTPTypes
import HTTPTypesFoundation
import Logging

public struct GitHubAssetRegistryClient: AssetRegistryClient {
    private let httpClient: any HTTPClient
    private let registryConfigs: GitHubRegistryConfigs?
    private let logger: Logger

    public init(httpClient: some HTTPClient, registryConfigs: GitHubRegistryConfigs?, logger: Logger) {
        self.httpClient = httpClient
        self.registryConfigs = registryConfigs
        self.logger = logger
    }

    public func fetchAssets(repositoryURL: URL, version: GitVersion) async throws -> AssetInformation {
        let assetURL = try GitHubURLBuilder.assetURL(repositoryURL, version: version)

        let assetResponse = try await fetchData(GitHubAssetResponse.self, requestURL: assetURL, repositoryURL: repositoryURL)
        let assets = assetResponse.assets.map { asset in
            Asset(fileName: asset.name, url: asset.browserDownloadURL)
        }
        return AssetInformation(tagName: assetResponse.tagName, assets: assets)
    }

    public func fetchAssetsApplyingExcludedVersions(
        repositoryURL: URL,
        version: GitVersion,
        excludingTargets: [String]
    ) async throws -> AssetInformation {
        let assetURL = try GitHubURLBuilder.releasesAssetURL(repositoryURL)
        let assetResponses = try await fetchData([GitHubAssetResponse].self, requestURL: assetURL, repositoryURL: repositoryURL)

        guard let matchedAssetResponse = assetResponses.first(where: { !excludingTargets.contains($0.tagName) }) else {
            throw AssetRegistryClientError.noMatchApplyingExcludedVersion
        }
        let assets = matchedAssetResponse.assets
            .map { Asset(fileName: $0.name, url: $0.browserDownloadURL) }
        return AssetInformation(tagName: matchedAssetResponse.tagName, assets: assets)
    }

    private func fetchData<T: Decodable>(_: T.Type, requestURL: URL, repositoryURL: URL) async throws -> T {
        var request = HTTPRequest(url: requestURL)
        request.headerFields = [
            .accept: "application/vnd.github+json",
            .gitHubAPIVersion: "2022-11-28"
        ]

        guard let repositoryHost = repositoryURL.host() else { fatalError("Unknown host") }
        if let config = registryConfigs?.config(for: repositoryURL) {
            logger.debug("GitHub token for \(repositoryHost) is passed from \(config.environmentVariable)")
            request.headerFields[.authorization] = "Bearer \(config.token)"
        } else {
            logger.debug("GitHub token for \(repositoryHost) is not provided.")
        }

        logger.debug("Request: \(repositoryURL)")
        logger.debug("Request: \(request.headerFields)")
        let (data, response) = try await httpClient.data(for: request)
        logger.debug("Response: \(data.humanReadableJSONString() ?? "No data")")
        logger.debug("Status: \(response.status)")

        if response.status == .notFound {
            throw AssetRegistryClientError.notFound
        }
        return try JSONDecoder().decode(T.self, from: data)
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
