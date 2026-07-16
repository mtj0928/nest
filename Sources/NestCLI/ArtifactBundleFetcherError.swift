import Foundation

/// An error produced while resolving, downloading, or validating an artifact bundle.
public enum ArtifactBundleFetcherError: LocalizedError {
    /// No artifact bundle was found in the resolved release assets.
    case noCandidates

    /// An operation requiring a release tag was requested without one.
    case noTagSpecified

    /// The artifact bundle does not contain a binary for the current target triple.
    case unsupportedTriple

    /// The downloaded artifact bundle does not match its expected checksum.
    case checksumMismatch(expected: String, actual: String)

    /// A localized description of the artifact bundle failure.
    public var errorDescription: String? {
        switch self {
        case .noCandidates: "No candidates for artifact bundle in the repository, please specify the file name."
        case .noTagSpecified: "No tag specified, please specify the tag."
        case .unsupportedTriple: "No binaries corresponding to the current triple."
        case .checksumMismatch(let expected, let actual):
            """
            The checksum of the downloaded file does not match the expected checksum.
            expected: \(expected)
            actual:   \(actual)
            """
        }
    }
}
