import Foundation

enum HTTPRedirectSecurity {
    static func redirectedRequest(_ request: URLRequest, response: HTTPURLResponse) -> URLRequest {
        if hasSameOrigin(response.url, request.url) {
            return request
        }

        var sanitizedRequest = request
        request.allHTTPHeaderFields?.keys
            .filter(SensitiveHTTPHeader.contains)
            .forEach { sanitizedRequest.setValue(nil, forHTTPHeaderField: $0) }
        return sanitizedRequest
    }

    private static func hasSameOrigin(_ sourceURL: URL?, _ destinationURL: URL?) -> Bool {
        guard let sourceURL,
              let destinationURL,
              let sourceScheme = sourceURL.scheme?.lowercased(),
              let destinationScheme = destinationURL.scheme?.lowercased(),
              let sourceHost = sourceURL.host()?.lowercased(),
              let destinationHost = destinationURL.host()?.lowercased()
        else {
            return false
        }
        return sourceScheme == destinationScheme
            && sourceHost == destinationHost
            && effectivePort(of: sourceURL) == effectivePort(of: destinationURL)
    }

    private static func effectivePort(of url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        return switch url.scheme?.lowercased() {
        case "http": 80
        case "https": 443
        default: nil
        }
    }
}
