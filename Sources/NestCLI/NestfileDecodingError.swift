import Foundation
import Yams

/// A nestfile parsing failure that does not include the input contents.
public enum NestfileDecodingError: LocalizedError, Equatable, Sendable {
    /// Invalid YAML syntax, with one-based line and column numbers.
    case invalidSyntax(line: Int, column: Int)

    /// Contents that do not match the nestfile format.
    case invalidFormat

    /// A diagnostic message containing no input values or YAML snippets.
    public var errorDescription: String? {
        switch self {
        case .invalidSyntax(let line, let column):
            "Invalid YAML at line \(line), column \(column)."
        case .invalidFormat:
            "Invalid nestfile format. Check the field types and required fields."
        }
    }

    init(_ error: any Error) {
        let yamlError: YamlError?
        if let decodingError = error as? DecodingError,
           case .dataCorrupted(let context) = decodingError {
            yamlError = context.underlyingError as? YamlError
        } else {
            yamlError = error as? YamlError
        }
        switch yamlError {
        case .scanner(_, _, let mark, _), .parser(_, _, let mark, _), .composer(_, _, let mark, _):
            self = .invalidSyntax(line: mark.line, column: mark.column)
        default:
            self = .invalidFormat
        }
    }
}
