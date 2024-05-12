import ArgumentParser
import Foundation
import NestCLI
import NestKit
import Logging

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install a repository"
    )

    @Argument(help: "A repository you want to install. (e.g., `owner/repository` or \"https://github.com/...\")")
    var repositoryURL: GitURL

    @Argument
    var version: GitVersion = .latestRelease

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        LoggingSystem.bootstrap()
        Configuration.default.logger.logLevel = verbose ? .trace : .info

        let executableBinaries = try await executableBinaryPreparer.fetchOrBuildBinaries(at: repositoryURL, version: version)
        for binary in executableBinaries {
            try nestFileManager.install(binary)
            logger.info("🪺 Success to install \(binary.commandName).", metadata: .color(.green))
        }
    }
}

extension InstallCommand {
    var executableBinaryPreparer: ExecutableBinaryPreparer { Configuration.default.executableBinaryPreparer }
    var nestFileManager: NestFileManager { Configuration.default.nestFileManager }
    var logger: Logger { Configuration.default.logger }
}
