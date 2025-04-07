import Foundation

/// A client that fetches information of assets which may contain an artifact bundle.
public protocol AssetRegistryClient: Sendable {

    /// Fetches information of assets in the repository which may contain an artifact bundle corresponding to the version
    /// - Parameters:
    ///   - repositoryURL: A url of a repository.
    ///   - version: A version of asset you want.
    /// - Returns: An asset information.
    func fetchAssets(repositoryURL: URL, version: GitVersion) async throws -> AssetInformation

    /// Fetches information of assets applying excluded targets in the repository which may contain an artifact bundle corresponding to the version
    /// - Parameters:
    ///   - repositoryURL: A url of a repository.
    ///   - version: latestAvailableRelease only.
    ///   - excludingTargets: excluding targets.
    /// - Returns: An asset information.
    func fetchAssetsApplyingExcludedTargets(repositoryURL: URL, version: GitVersion, excludingTargets: [String]) async throws -> AssetInformation
}

public struct AssetInformation: Sendable {
    public var tagName: String
    public var assets: [Asset]

    public init(tagName: String, assets: [Asset]) {
        self.tagName = tagName
        self.assets = assets
    }
}

public struct Asset: Sendable, Equatable {
    /// A file name of this asset.
    public var fileName: String

    /// A url indicating a place of this asset.
    public var url: URL

    public init(fileName: String, url: URL) {
        self.fileName = fileName
        self.url = url
    }
}

// MARK: - Errors

public enum AssetRegistryClientError: LocalizedError, Hashable, Sendable {
    case notFound
    case noMatchApplyingExcludedTarget

    public var errorDescription: String? {
        switch self {
        case .notFound: "Not found for the repository."
        case .noMatchApplyingExcludedTarget: "Not match applying excluded version."
        }
    }
}

