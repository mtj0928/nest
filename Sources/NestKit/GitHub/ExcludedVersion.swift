/// {owner}/{repo} and (optional) version pairs to exclude
public struct ExcludedVersion: Equatable, Sendable {
    /// A reference to a repository.
    /// {owner}/{repo}
    public let reference: String
    public let target: String?

    public init(reference: String, target: String?) {
        self.reference = reference
        self.target = target
    }
}

