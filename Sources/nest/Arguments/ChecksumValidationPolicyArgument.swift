import ArgumentParser
import NestCLI

/// A command-line argument for selecting checksum validation behavior.
enum ChecksumValidationPolicyArgument: String, ExpressibleByArgument {
    /// Skips checksum validation.
    case skip

    /// Allows missing checksums with a warning.
    case warn

    /// Requires checksums and treats missing checksums as an error.
    case require

    /// The checksum validation policy represented by this argument.
    var policy: ChecksumValidationPolicy {
        switch self {
        case .skip:
            .skip
        case .warn:
            .warn
        case .require:
            .require
        }
    }
}
