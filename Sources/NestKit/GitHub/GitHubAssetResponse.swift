import Foundation

struct GitHubAssetResponse: Codable {
    let assets: [GitHubAsset]
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case assets
        case tagName = "tag_name"
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
