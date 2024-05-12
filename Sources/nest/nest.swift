import ArgumentParser
import NestKit
import Logging

@main
struct Nest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nest",
        subcommands: [InstallCommand.self]
    )
}

extension Configuration {
    static var `default` = Configuration(
        urlSession: .shared,
        fileManager: .default,
        logger: Logger(label: "com.github.mtj0928.nest")
    )
}
