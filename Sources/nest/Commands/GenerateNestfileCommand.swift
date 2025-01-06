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
        let url = URL(filePath: "./nestfile.yaml")
        if FileManager.default.fileExists(atPath: url.path()) {
            logger.error("nestfile exists in the current directory.", metadata: .color(.red))
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
            nestPath: ProcessInfo.processInfo.nestPath,
            serverTokenEnvironmentVariableNames: [:],
            logLevel: verbose ? .trace : .info
        )

        return configuration.logger
    }
}


let templateString = """
nestPath: ./.nest
targets:
  - reference: realm/SwiftLint
"""
