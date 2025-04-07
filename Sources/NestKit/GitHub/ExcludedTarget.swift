/// {owner}/{repo} and (optional) version pairs to exclude
public struct ExcludedTarget: Equatable, Sendable {
    /// A reference to a repository.
    /// {owner}/{repo}
    public let reference: String
    public let version: String?

    public init(reference: String, version: String?) {
        self.reference = reference
        self.version = version
    }
}

