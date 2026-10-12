import Foundation
import NestKit

enum TargetLogFormatter {
    /// Formats target references for diagnostics without URL credentials, query, or fragment.
    /// Unrecognized inputs are replaced with a placeholder instead of being echoed.
    static func description(of target: String) -> String {
        if let sshURL = SSHURL(string: target) {
            return GitURL.ssh(sshURL).logDescription
        }
        if let url = URL(string: target), url.scheme != nil {
            return url.logDescription
        }
        if target.wholeMatch(of: /[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)+/) != nil {
            return target
        }
        return "<target>"
    }
}
