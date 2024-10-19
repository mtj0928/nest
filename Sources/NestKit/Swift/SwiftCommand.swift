import Foundation
import Logging

public struct SwiftCommand {
    private let executor: any ProcessExecutor

    public init(executor: some ProcessExecutor) {
        self.executor = executor
    }

    func run(_ argument: String...) async throws -> String {
        let swift = try await executor.which("swift")
        return try await executor.execute(command: swift, argument)
    }
}
