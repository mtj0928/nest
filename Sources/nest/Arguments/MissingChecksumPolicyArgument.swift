import ArgumentParser
import NestCLI

/// A command-line argument for selecting how an artifact bundle without a checksum is handled.
enum MissingChecksumPolicyArgument: String, ExpressibleByArgument {
    /// Allows a missing checksum without validation or a warning.
    case skip

    /// Allows a missing checksum with a warning.
    case warn

    /// Treats a missing checksum as an error.
    case require

    /// The missing-checksum policy represented by this argument.
    var policy: MissingChecksumPolicy {
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
