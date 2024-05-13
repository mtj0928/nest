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

    @Argument(help: """
        A git repository or a URL of an artifactbunlde you want to install. (e.g., `owner/repository`, `https://github.com/...`, and `https://examaple.com/../foo.artifactbundle.zip`)
        """)
    var target: InstallTarget

    @Argument
    var version: GitVersion = .latestRelease

    @Flag(name: .shortAndLong)
    var verbose: Bool = false

    mutating func run() async throws {
        LoggingSystem.bootstrap()
        Configuration.default.logger.logLevel = verbose ? .trace : .info

        let executableBinaries = switch target {
        case .git(let gitURL):
            try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(at: gitURL, version: version)
        case .artifactBundle(let url):
            try await executableBinaryPreparer.fetchArtifactBundle(at: url)
        }

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
