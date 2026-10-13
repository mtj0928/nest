import Foundation
import Logging
import Subprocess

/// Runs commands with captured output or interactive standard streams.
public protocol ProcessExecutor: Sendable {
    /// Runs a command and returns its standard output, throwing if execution fails.
    func execute(command: String, _ arguments: [String]) async throws -> String

    /// Executes the given command with the given arguments.
    /// All inputs, outputs and errors are exposed to users unlike ``execute(command:_:)``.
    /// So user can input texts if the command requires.
    /// The returned value indicates the status of the results of the command.
    func executeInteractively(command: String, _ arguments: [String]) async throws -> Int32
}

extension ProcessExecutor {
    /// Runs a command with variadic arguments and returns its standard output.
    public func execute(command: String, _ arguments: String...) async throws -> String {
        try await execute(command: command, arguments)
    }

    /// Runs a command with variadic arguments using interactive standard streams.
    public func executeInteractively(command: String, _ arguments: String...) async throws -> Int32 {
        try await executeInteractively(command: command, arguments)
    }

    /// Finds a command on the executable search path.
    public func which(_ command: String) async throws -> String {
        try await execute(command: "/usr/bin/which", command)
    }
}

/// Executes commands with Subprocess and logs captured output.
public struct NestProcessExecutor: ProcessExecutor {
    let currentDirectoryURL: URL?
    let environment: [String: String]
    let logger: Logging.Logger
    let logLevel: Logging.Logger.Level

    /// Creates an executor with the given working directory, filtered environment, and output log level.
    public init(
        currentDirectory: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        removingEnvironmentVariables: Set<String> = [],
        logger: Logging.Logger,
        logLevel: Logging.Logger.Level = .debug
    ) {
        self.currentDirectoryURL = currentDirectory
        self.environment = environment.filter { !removingEnvironmentVariables.contains($0.key) }
        self.logger = logger
        self.logLevel = logLevel
    }

    /// Runs a command, logs both output streams, and returns standard output with surrounding whitespace removed.
    /// Throws if the command cannot be launched or does not exit successfully.
    public func execute(command: String, _ arguments: [String]) async throws -> String {
        logger.debug("$ \(URL(fileURLWithPath: command).lastPathComponent) (argument count: \(arguments.count))")
        let result = try await Subprocess.run(
            configuration(command: command, arguments: arguments),
            input: .none,
            output: .sequence,
            error: .sequence
        ) { execution in
            async let output = collectOutput(execution.standardOutput, metadata: nil)
            async let error = collectOutput(execution.standardError, metadata: .color(.red))
            let (standardOutput, _) = try await (output, error)
            return standardOutput
        }
        guard result.terminationStatus.isSuccess else {
            throw Error.failed
        }
        return result.closureResult
    }

    /// Runs a command using the current standard input, output, and error streams.
    /// Returns the exit code or the signal that terminated the command.
    public func executeInteractively(command: String, _ arguments: [String]) async throws -> Int32 {
        logger.debug("$ \(URL(fileURLWithPath: command).lastPathComponent) (argument count: \(arguments.count))")
        let result = try await Subprocess.run(
            configuration(command: command, arguments: arguments),
            input: .currentStandardInput,
            output: .currentStandardOutput,
            error: .currentStandardError
        )
        switch result.terminationStatus {
        case .exited(let code), .signaled(let code):
            return code
        }
    }

    private func configuration(command: String, arguments: [String]) -> Subprocess.Configuration {
        let environmentValues = environment.map { (Environment.Key(stringLiteral: $0.key), $0.value) }
        return Subprocess.Configuration(
            executable: .path(.init(URL(fileURLWithPath: command).path(percentEncoded: false))),
            arguments: .init(arguments),
            environment: .custom(Dictionary(uniqueKeysWithValues: environmentValues)),
            workingDirectory: currentDirectoryURL.map { .init($0.path(percentEncoded: false)) }
        )
    }

    private func collectOutput(
        _ sequence: SubprocessOutputSequence,
        metadata: Logger.Metadata?
    ) async throws -> String {
        var output = ""
        // Split only at LF so CR and Unicode separators inside the command's output are preserved.
        let lines = sequence.strings(
            separatedBy: .unicodeScalarSequence("\n".unicodeScalars),
            bufferingPolicy: .unbounded
        )
        for try await line in lines {
            output += line + "\n"
            let message = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                logger.log(level: logLevel, "\(message)", metadata: metadata)
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension NestProcessExecutor {
    private enum Error: Swift.Error {
        case failed
    }
}
