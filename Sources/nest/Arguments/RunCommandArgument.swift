import NestKit
import Logging

struct SubCommandOfRunCommand: Sendable, Hashable {
    let repository: GitURL
    let arguments: [String]

    enum ParseError: Error {
        case emptyArguments
        case invalidFormat
    }

    init(arguments: [String]) throws(ParseError) {
        guard !arguments.isEmpty else {
            throw ParseError.emptyArguments
        }
        guard let repository = GitURL.parse(from: arguments[0]) else {
            throw ParseError.invalidFormat
        }

        self.repository = repository
        self.arguments = if arguments.count >= 2 {
            Array(arguments[1...])
        } else {
            []
        }
    }
}
