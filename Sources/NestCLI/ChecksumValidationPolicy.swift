/// Defines how downloaded artifact bundle checksums are validated.
package enum ChecksumValidationPolicy: Equatable, Sendable {
    /// Skips checksum validation.
    case skip

    /// Allows missing checksums with a warning.
    case warn

    /// Requires checksums and treats missing checksums as an error.
    case require
}
