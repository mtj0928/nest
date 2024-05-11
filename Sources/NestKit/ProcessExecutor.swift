import Foundation

struct ProcessExecutor {
    let currentDirectoryURL: URL?

    init(currentDirectory: URL? = nil) {
        self.currentDirectoryURL = currentDirectory
    }

    func execute(command: String, _ arguments: String...) -> AsyncThrowingStream<StreamElement, any Error> {
        _execute(command: command, arguments.map { $0 })
    }

    func executeAndWait(command: String, _ arguments: String...) async throws -> String {
        var result = ""
        for try await element in _execute(command: command, arguments.map { $0 }) {
            switch element {
            case .output(let string): result += string
            case .error: break
            }
        }
        return result
    }

    private func _execute(command: String, _ arguments: [String]) -> AsyncThrowingStream<StreamElement, any Error> {
        return AsyncThrowingStream { continuous in
            let executableURL = URL(fileURLWithPath: command)
            do {
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
                    continuous.yield(.output(string))
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
                    continuous.yield(.error(string))
                }

                try process.run()
                process.waitUntilExit()
                let result = process.terminationReason == .exit && process.terminationStatus == 0
                if result {
                    continuous.finish()
                } else {
                    continuous.finish(throwing: ProcessExecutorError.failed)
                }
            } catch {
                continuous.finish(throwing: error)
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
