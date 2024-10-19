import Foundation
import Testing
import NestKit

struct MockExecutorBuilder: ProcessExecutorBuilder {
    let executorClosure: @Sendable (String, [String]) async throws -> String

    init(executorClosure: @escaping @Sendable (String, [String]) -> String) {
        self.executorClosure = executorClosure
    }

    init(dummy: [String: String]) {
        self.executorClosure = { command, arguments in
            let command = ([command] + arguments).joined(separator: " ")
            guard let result = dummy[command] else {
                Issue.record("Unexpected commend: \(command)")
                return ""
            }
            return result
        }
    }

    func build(currentDirectory: URL?) -> any NestKit.ProcessExecutor {
        MockProcessExecutor(executorClosure: executorClosure)
    }
}

struct MockProcessExecutor: ProcessExecutor {
    let executorClosure: @Sendable (String, [String]) async throws -> String

    init(executorClosure: @escaping @Sendable (String, [String]) async throws -> String) {
        self.executorClosure = executorClosure
    }

    init(dummy: [String: String]) {
        self.executorClosure = { command, arguments in
            let command = ([command] + arguments).joined(separator: " ")
            guard let result = dummy[command] else {
                Issue.record("Unexpected commend: \(command)")
                return ""
            }
            return result
        }
    }

    func execute(command: String, _ arguments: [String]) async throws -> String {
        try await executorClosure(command, arguments)
    }
}
