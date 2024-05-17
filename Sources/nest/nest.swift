import ArgumentParser
import NestKit
import Logging

@main
struct Nest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nest",
        subcommands: [
            InstallCommand.self,
            UninstallCommand.self,
            ListCommand.self
        ]
    )
}

extension Configuration {
    static let `default` = Configuration(
        urlSession: .shared,
        fileManager: .default,
        logger: Logger(label: "com.github.mtj0928.nest")
    )
}
