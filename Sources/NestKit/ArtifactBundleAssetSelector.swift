public struct ArtifactBundleAssetSelector {
    public init() {}

    /// Select an artifact bundle from the given GitHun assets.
    /// If there is no proper asset, the function returns `nil`.
    public func selectArtifactBundle(from assets: [Asset], fileName: String?) -> Asset? {
        assets.first(where: { $0.fileName == fileName })
        ?? assets.first(where: { $0.fileName.contains("artifactbundle") })
    }
}
