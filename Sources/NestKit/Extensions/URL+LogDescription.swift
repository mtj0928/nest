import Foundation

extension URL {
    /// Formats an HTTP URL for logs without credentials, query, or fragment.
    ///
    /// Keeps the scheme, host, port, and path. Secrets embedded in the path are not removed.
    /// Returns a placeholder for unsupported or incomplete URLs without changing the original URL.
    package var logDescription: String {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return "<URL>"
        }

        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil

        return components.string ?? "<URL>"
    }
}
