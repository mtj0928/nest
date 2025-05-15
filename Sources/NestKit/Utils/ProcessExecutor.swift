import Foundation
import Logging
import os

public protocol ProcessExecutor: Sendable {
    func execute(command: String, _ arguments: [String]) async throws -> String
}

extension ProcessExecutor {
    public func execute(command: String, _ arguments: String...) async throws -> String {
        try await execute(command: command, arguments)
    }

    public func which(_ command: String) async throws -> String {
        try await execute(command: "/usr/bin/which", command)
    }
}

public struct NestProcessExecutor: ProcessExecutor {
    let currentDirectoryURL: URL?
    let logger: Logging.Logger
    let logLevel: Logging.Logger.Level

    public init(currentDirectory: URL? = nil, logger: Logging.Logger, logLevel: Logging.Logger.Level = .debug) {
        self.currentDirectoryURL = currentDirectory
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
        logger.log(level: logLevel, "$ \(command) \(arguments.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuous in
            let executableURL = URL(fileURLWithPath: command)
            do {
                let results = OSAllocatedUnfairLock(initialState: [StreamElement]())

                let process = Process()
                process.currentDirectoryURL = currentDirectoryURL
                process.executableURL = executableURL
                process.arguments = arguments

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
