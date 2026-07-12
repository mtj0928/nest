/// A user-scope artifact bundle ZIP cache option.
public enum ArtifactBundleZIPCacheOption: Sendable {
    /// Enables the user-scope artifact bundle ZIP cache.
    case enableCache(ArtifactBundleZIPCache)

    /// Disables the user-scope artifact bundle ZIP cache.
    case disableCache
}
