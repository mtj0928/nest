/// Defines how an artifact bundle without a checksum is handled.
package enum MissingChecksumPolicy: Equatable, Sendable {
    /// Allows a missing checksum without validation or a warning.
    case skip

    /// Allows a missing checksum with a warning.
    case warn

    /// Treats a missing checksum as an error.
    case require
}
