import Foundation
import Logging

public struct TripleDetector {
    private let swiftCommand: SwiftCommand

    public init(swiftCommand: SwiftCommand) {
        self.swiftCommand = swiftCommand
    }

    public func detect() async throws -> String {
        try await swiftCommand.targetInfo().target.unversionedTriple
    }
}
