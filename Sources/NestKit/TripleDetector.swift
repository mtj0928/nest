import Foundation
import Logging

public struct TripleDetector {
    private let swiftCommand: SwiftCommand

    public init(logger: Logger) {
        self.swiftCommand = SwiftCommand(logger: logger)
    }

    public func detect() async throws -> String {
        try await swiftCommand.targetInfo().target.unversionedTriple
    }
}
