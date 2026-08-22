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
        let requestTarget = try GitHubURLBuilder.assetURL(repositoryURL, version: version)

        let assetResponse = try await fetchData(GitHubAssetResponse.self, requestTarget: requestTarget)
        let assets = assetResponse.assets.map { asset in
            Asset(fileName: asset.name, url: asset.browserDownloadURL)
        }
        return AssetInformation(tagName: assetResponse.tagName, assets: assets)
    }

    public func fetchAssetsApplyingExcludedTargets(
        repositoryURL: URL,
        version: GitVersion,
        excludingTargets: [String]
    ) async throws -> AssetInformation {
        let requestTarget = try GitHubURLBuilder.releasesAssetURL(repositoryURL)
        let assetResponses = try await fetchData([GitHubAssetResponse].self, requestTarget: requestTarget)

        guard let matchedAssetResponse = assetResponses.first(where: { !excludingTargets.contains($0.tagName) }) else {
            throw AssetRegistryClientError.noMatchApplyingExcludedTarget
        }
        let assets = matchedAssetResponse.assets
            .map { Asset(fileName: $0.name, url: $0.browserDownloadURL) }
        return AssetInformation(tagName: matchedAssetResponse.tagName, assets: assets)
    }

    private func fetchData<T: Decodable>(_: T.Type, requestTarget: GitHubURLBuilder.APIRequestTarget) async throws -> T {
        var request = HTTPRequest(url: requestTarget.url)
        request.headerFields = [
            .accept: "application/vnd.github+json",
            .gitHubAPIVersion: "2022-11-28"
        ]

        let registryHost = requestTarget.registryHost
        if let config = registryConfigs?.config(for: registryHost) {
            logger.debug("GitHub token for \(registryHost.hostname) is passed from \(config.environmentVariable)")
            request.headerFields[.authorization] = "Bearer \(config.token)"
        } else {
            logger.debug("GitHub token for \(registryHost.hostname) is not provided.")
        }

        logger.debug("Request: \(HTTPLogRedactor.redactedDescription(of: request))")
        let (data, response) = try await httpClient.data(for: request)
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
