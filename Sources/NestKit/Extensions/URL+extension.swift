import Foundation
import UniformTypeIdentifiers

extension URL {
    /// `owner/repo` format
    /// `pathComponents[1]` must be specified as owner and `pathComponents[2]` must be specified as repository
    public var reference: String? {
        guard pathComponents.count >= 3 else { return nil }
        let owner = pathComponents[1]
        let repo = pathComponents[2].replacingOccurrences(of: ".\(pathExtension)", with: "")
        return "\(owner)/\(repo)"
    }

    public var fileNameWithoutPathExtension: String {
        lastPathComponent.replacingOccurrences(of: ".\(pathExtension)", with: "")
    }

    public var needsUnzip: Bool {
        let utType = UTType(filenameExtension: pathExtension)
        return utType?.conforms(to: .zip) ?? false
    }

    /// Parses the given string and ensures it uses the HTTPS scheme.
    ///
    /// Use this for any URL that nest will fetch and execute downstream
    /// (artifact bundle ZIPs and similar). Plain-text HTTP makes integrity
    /// checks meaningless because a network attacker can swap both the
    /// payload and any matching checksum metadata.
    public static func httpsURL(from urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLValidationError.invalid(urlString)
        }
        guard url.scheme?.lowercased() == "https" else {
            throw URLValidationError.insecureScheme(urlString)
        }
        return url
    }
}

public enum URLValidationError: LocalizedError, Equatable, Sendable {
    case invalid(String)
    case insecureScheme(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let urlString):
            "Invalid URL: \(urlString)"
        case .insecureScheme(let urlString):
            """
            Insecure URL "\(urlString)". \
            nest only accepts HTTPS URLs for artifact bundle downloads, \
            because plain-text HTTP allows a network attacker to swap both \
            the payload and the checksum.
            """
        }
    }
}
