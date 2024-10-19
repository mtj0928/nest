import Foundation
import Logging

public protocol ProcessExecutorBuilder: Sendable {
    func build(currentDirectory: URL?) -> ProcessExecutor
}

extension ProcessExecutorBuilder {
    public func build() -> ProcessExecutor {
        build(currentDirectory: nil)
    }
}

public struct NestProcessExecutorBuilder: ProcessExecutorBuilder {
    public let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func build(currentDirectory: URL?) -> any ProcessExecutor {
        NestProcessExecutor(currentDirectory: currentDirectory, logger: logger)
    }
}
