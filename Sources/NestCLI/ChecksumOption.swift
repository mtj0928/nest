/// A resolved action for handling an artifact bundle checksum.
///
/// Resolve the expected checksum and any missing-checksum policy before passing this value to
/// ``ArtifactBundleFetcher``. Each case represents one unambiguous action for the fetcher.
public enum ChecksumOption {
    /// Verifies that the downloaded artifact bundle matches the expected checksum.
    case needsCheck(expected: String)

    /// Calculates the checksum and reports it without performing verification.
    case printActual(handler: (String) -> Void)

    /// Accepts the artifact bundle without calculating or verifying its checksum.
    case skip

    /// Accepts an artifact bundle missing a checksum and prints a migration warning.
    case warnOnMissingChecksum(target: String)

    /// Defers a configuration error until an artifact bundle is selected for download.
    case unresolvable(ChecksumOptionError)
}
