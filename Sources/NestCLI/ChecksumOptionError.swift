import Foundation

/// An error that prevents resolving an artifact bundle checksum action.
public enum ChecksumOptionError: LocalizedError, Equatable, Sendable {
    /// A target in a nestfile is missing a required checksum.
    case missingChecksum(target: String)

    /// An install target is missing a required checksum.
    case missingInstallChecksum(target: String)

    /// A localized description explaining how to resolve the missing checksum.
    public var errorDescription: String? {
        switch self {
        case .missingChecksum(let target):
            """
            Missing checksum for "\(target)" in the nestfile.
            Run `nest update-nestfile <path>` to populate checksums, \
            or pass `--checksum-policy warn` or `--checksum-policy skip` to continue without verification.
            """
        case .missingInstallChecksum(let target):
            """
            Missing checksum for "\(target)".
            Pass `--checksum <value>` to verify the downloaded file, \
            or pass `--checksum-policy warn` or `--checksum-policy skip` to continue without verification.
            """
        }
    }
}
