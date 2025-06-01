import Foundation
import Testing
import NestKit

public struct MockExecutorBuilder: ProcessExecutorBuilder {
    let executorClosure: @Sendable (String, [String]) async throws -> String

    public init(executorClosure: @escaping @Sendable (String, [String]) -> String) {
        self.executorClosure = executorClosure
    }

    public init(dummy: [String: String]) {
        self.executorClosure = { command, arguments in
            let command = ([command] + arguments).joined(separator: " ")
            guard let result = dummy[command] else {
                Issue.record("Unexpected commend: \(command)")
                return ""
            }
            return result
        }
    }

    public func build(currentDirectory: URL?) -> any NestKit.ProcessExecutor {
        MockProcessExecutor(executorClosure: executorClosure)
    }
}

public struct MockProcessExecutor: ProcessExecutor {
    let executorClosure: @Sendable (String, [String]) async throws -> String

    public init(executorClosure: @escaping @Sendable (String, [String]) async throws -> String) {
        self.executorClosure = executorClosure
    }

    public init(dummy: [String: String]) {
        self.executorClosure = { command, arguments in
            let command = ([command] + arguments).joined(separator: " ")
            guard let result = dummy[command] else {
                Issue.record("Unexpected commend: \(command)")
                return ""
            }
            return result
        }
    }

    public func execute(command: String, _ arguments: [String]) async throws -> String {
        try await executorClosure(command, arguments)
    }
    
    public func executeInteractively(command: String, _ arguments: [String]) async throws -> Int32 {
        // For testing, just call execute and exit
        _ = try await executorClosure(command, arguments)
        return 0
    }
}
