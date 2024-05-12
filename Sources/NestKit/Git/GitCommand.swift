import Foundation
import Logging

public struct GitCommand {
    private let executor: ProcessExecutor

    public init(currentDirectoryURL: URL? = nil, logger: Logger) {
        self.executor = ProcessExecutor(currentDirectory: currentDirectoryURL, logger: logger)
    }

    func run(_ argument: String...) async throws -> String {
        let swift = try await executor.which("git")
        return try await executor.executeAndWait(command: swift, argument)
    }
}

extension GitCommand {
    public func currentBranch() async throws -> String {
        try await run("rev-parse", "--abbrev-ref", "HEAD")
    }

    public func clone(repositoryURL: GitURL, tag: String?, to destinationPath: URL) async throws {
        let cloneURL: String = switch repositoryURL {
        case .url(let url): url.absoluteString
        case .ssh(let sshURL): sshURL.stringURL
        }

        if let tag {
            _ = try await run("clone", "--branch", tag, cloneURL, destinationPath.path())
        } else {
            _ = try await run("clone", cloneURL, destinationPath.path())
        }
    }

}
