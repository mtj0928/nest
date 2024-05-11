public struct ArtifactBundleAssetSelector {
    public init() {}

    public func selectArtifactBundle(from assets: [Asset]) -> Asset? {
        assets.first(where: { $0.fileName.contains("artifactbundle") })
    }
}
