public enum GitVersion: Sendable, Equatable {
    case latestRelease
    case tag(String)

    public var description: String {
        switch self {
        case .latestRelease: "latest"
        case .tag(let string): string
        }
    }
}
