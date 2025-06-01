import Foundation
import Logging
import os

public protocol ProcessExecutor: Sendable {
    func execute(command: String, _ arguments: [String]) async throws -> String

    /// Executes the given command with the given arguments.
    /// All inputs, outputs and errors are exposed to users unlike ``execute(command:_:)``.
    /// So user can input texts if the command requires.
    /// The returned value indicates the status of the results of the command.
    func executeInteractively(command: String, _ arguments: [String]) async throws -> Int32
}

extension ProcessExecutor {
    public func execute(command: String, _ arguments: String...) async throws -> String {
        try await execute(command: command, arguments)
    }

    public func executeInteractively(command: String, _ arguments: String...) async throws -> Int32 {
        try await executeInteractively(command: command, arguments)
    }

    public func which(_ command: String) async throws -> String {
        try await execute(command: "/usr/bin/which", command)
    }
}

public struct NestProcessExecutor: ProcessExecutor {
    let currentDirectoryURL: URL?
    let environment: [String: String]
    let logger: Logging.Logger
    let logLevel: Logging.Logger.Level

    public init(
        currentDirectory: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        logger: Logging.Logger,
        logLevel: Logging.Logger.Level = .debug,
    ) {
        self.currentDirectoryURL = currentDirectory
        self.environment = environment
        self.logger = logger
        self.logLevel = logLevel
    }

    public func execute(command: String, _ arguments: [String]) async throws -> String {
        let elements = try await _execute(command: command, arguments.map { $0 })
        return elements.compactMap { element in
            switch element {
            case .output(let string): string
            case .error: nil
            }
        }.joined()
    }

    private func _execute(command: String, _ arguments: [String]) async throws -> [StreamElement] {
        logger.debug("$ \(command) \(arguments.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuous in
            let executableURL = URL(fileURLWithPath: command)
            do {
                let results = OSAllocatedUnfairLock(initialState: [StreamElement]())

                let process = Process()
                process.currentDirectoryURL = currentDirectoryURL
                process.executableURL = executableURL
                process.arguments = arguments
                process.environment = environment

                let outputPipe = Pipe()
                process.standardOutput = outputPipe

                outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                    let availableData = fileHandle.availableData
                    guard availableData.count != 0,
                          let string = String(data: availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !string.isEmpty
                    else {
                        return
                    }
                    logger.log(level: logLevel, "\(string)")
                    results.withLock { $0 += [.output(string)] }
                }

                let errorPipe = Pipe()
                process.standardError = errorPipe
                errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                    let availableData = fileHandle.availableData
                    guard availableData.count != 0,
                          let string = String(data: availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !string.isEmpty
                    else {
                        return
                    }
                    logger.log(level: logLevel, "\(string)", metadata: .color(.red))
                    results.withLock { $0 += [.error(string)] }
                }

                try process.run()
                process.waitUntilExit()

                // [Workaround] Sometimes, this code is executes before all events of `readabilityHandler` are addressed.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let result = process.terminationReason == .exit && process.terminationStatus == 0
                    if result {
                        let returnedValue = results.withLock { $0 }
                        continuous.resume(returning: returnedValue)
                    } else {
                        continuous.resume(throwing: ProcessExecutorError.failed)
                    }
                }
            } catch {
                continuous.resume(throwing: error)
            }
        }
    }

    public func executeInteractively(command: String, _ arguments: [String]) async throws -> Int32 {
        logger.debug("$ \(command) \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.environment = environment

        if let currentDirectoryURL {
            process.currentDirectoryURL = currentDirectoryURL
        }

        try process.run()
        tcsetpgrp(STDIN_FILENO, process.processIdentifier)
        process.waitUntilExit()
        return process.terminationStatus
    }
}

enum StreamElement {
    case output(String)
    case error(String)

    var text: String {
        switch self {
        case .output(let text): return text
        case .error(let text): return text
        }
    }
}

enum ProcessExecutorError: Error {
    case failed
}
