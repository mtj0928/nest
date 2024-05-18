import ArgumentParser
import Foundation
import NestCLI
import NestKit
import Logging

struct GenerateNestfileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-nestfile",
        abstract: "Generates a sample nestfile into the current directory."
    )

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    @MainActor mutating func run() async throws {
        let logger = setUp()
        let url = URL(filePath: "./nestfile.pkl")
        if FileManager.default.fileExists(atPath: url.path()) {
            logger.error("nestfile exists in the current fdirectory.", metadata: .color(.red))
            return
        }
        try templateString.write(to: url, atomically: true, encoding: .utf8)
        logger.error("📄 nestfile was generated.")
    }
}

extension GenerateNestfileCommand {
    private func setUp() -> Logger {
        LoggingSystem.bootstrap()
        let configuration = Configuration.make(
            nestPath: ProcessInfo.processInfo.nesPath,
            logLevel: verbose ? .trace : .info
        )

        return configuration.logger
    }
}


let templateString = """
amends "https://github.com/mtj0928/nest/releases/download/0.0.7/Nestfile.pkl" // Do not remove this line.

artifacts = new Listing {
  // Example 1: Specify a repository
  new Repository {
    reference = "mtj0928/nest" // or htpps://github.com/mtj0928/nest
    version = "0.0.7" // (Optional) If version doesn't exit, the latest release will be used.
  }

  // Example 2: Specify zip URL directly
  "https://github.com/mtj0928/nest/releases/download/0.0.7/nest-macos.artifactbundle.zip"
}
"""
