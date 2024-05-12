import Foundation

public protocol GitRepositoryClient: Sendable {
    func fetchAssets(repositoryURL: URL, version: GitVersion) async throws -> AssetInformation
}

public struct AssetInformation: Sendable {
    public var tagName: String
    public var assets: [Asset]

    public init(tagName: String, assets: [Asset]) {
        self.tagName = tagName
        self.assets = assets
    }
}

public struct Asset: Sendable {
    public var fileName: String
    public var url: URL

    public init(fileName: String, url: URL) {
        self.fileName = fileName
        self.url = url
    }
}
