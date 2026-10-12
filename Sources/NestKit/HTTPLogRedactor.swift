import HTTPTypes

enum HTTPLogRedactor {
    static func redactedDescription(of request: HTTPRequest) -> String {
        let url = request.url?.logDescription ?? "<unknown URL>"
        let headers = request.headerFields
            .map { field in
                let value = safeHeaderNames.contains(field.name.canonicalName.lowercased()) ? field.value : "<redacted>"
                return "\(field.name): \(value)"
            }
            .sorted()
            .joined(separator: ", ")
        return "\(request.method) \(url), headers: [\(headers)]"
    }

    private static let safeHeaderNames: Set<String> = [
        "accept",
        "x-github-api-version"
    ]
}
