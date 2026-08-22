enum SensitiveHTTPHeader {
    static func contains(_ headerName: String) -> Bool {
        let normalizedName = headerName.lowercased()
        if explicitlySensitiveNames.contains(normalizedName) {
            return true
        }
        if sensitiveFragments.contains(where: normalizedName.contains) {
            return true
        }
        return normalizedName == "key" || normalizedName.hasSuffix("-key")
    }

    private static let explicitlySensitiveNames: Set<String> = [
        "authorization",
        "cookie",
        "proxy-authorization",
        "set-cookie"
    ]
    private static let sensitiveFragments = [
        "api-key",
        "authentication",
        "authorization",
        "credential",
        "secret",
        "signature",
        "token"
    ]
}
