import CryptoKit
import Foundation

/// Resolves stable user-scope cache locations for artifact bundle ZIP files.
public struct ArtifactBundleZIPCache: Sendable {
    private static let maximumReadablePathDepth = 8

    /// The root directory where cached ZIP files are stored.
    public let directory: URL

    /// Creates a cache rooted at the given directory.
    public init(directory: URL) {
        self.directory = directory
    }

    /// Returns the cache file URL corresponding to a remote artifact bundle ZIP URL.
    public func fileURL(for remoteURL: URL) -> URL {
        let scheme = (remoteURL.scheme ?? "unknown-scheme").artifactBundleZIPCachePathComponent
        let host = (remoteURL.host() ?? "unknown-host").artifactBundleZIPCachePathComponent
        let authority = remoteURL.port.map { "\(host)-\($0)" } ?? host
        let readablePathComponents = remoteURL.pathComponents
            .filter { $0 != "/" }
            .dropLast()
            .prefix(Self.maximumReadablePathDepth)
            .map(\.artifactBundleZIPCachePathComponent)
        let cacheDirectory = ([scheme, authority] + readablePathComponents)
            .reduce(directory) { $0.appending(component: $1) }
        let remoteFileStem = remoteURL.deletingPathExtension().lastPathComponent
        let readableFileStem = (remoteFileStem.isEmpty ? "artifact-bundle" : remoteFileStem)
            .artifactBundleZIPCachePathComponent

        return cacheDirectory.appending(component: "\(readableFileStem)-\(cacheKey(for: remoteURL)).zip")
    }

    private func cacheKey(for remoteURL: URL) -> String {
        var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        let cacheIdentity = components?.string ?? remoteURL.absoluteString
        return SHA256.hash(data: Data(cacheIdentity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension String {
    var artifactBundleZIPCachePathComponent: String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        let encoded = addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? "unknown"
        let nonempty = encoded.isEmpty ? "unknown" : encoded
        let traversalSafe = switch nonempty {
        case ".", "..": "_\(nonempty)"
        default: nonempty
        }
        return String(traversalSafe.prefix(80))
    }
}
