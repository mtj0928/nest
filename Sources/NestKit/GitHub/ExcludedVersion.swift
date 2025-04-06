/// {owner}/{repo} and (optional) version pairs to exclude
public struct ExcludedVersion: Equatable, Sendable {
    /// A reference to a repository.
    /// {owner}/{repo}
    public let reference: String
    public let target: String?

    public init?(argument: String) {
        let split = argument.split(separator: "@")
        guard split.count == 1 || split.count == 2 else { return nil }
        self = .init(reference: String(split[0]), target: split.count == 2 ? String(split[1]) : nil)
    }

    init(reference: String, target: String?) {
        self.reference = reference
        self.target = target
    }
}

