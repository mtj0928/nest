import Foundation
import NestCLI
import NestTestHelpers
import Testing

struct NestfileDecodingErrorTests {
    @Test(arguments: [
        ("targets: [https://example.com/tool.zip?token=PARSER_SECRET, }", "PARSER_SECRET", 1),
        ("targets:\n\t- reference: SCANNER_SECRET", "SCANNER_SECRET", 2),
        ("targets: [*ALIAS_SECRET]", "ALIAS_SECRET", 1)
    ])
    func syntaxErrorsKeepLocationWithoutInputContents(input: String, secret: String, expectedLine: Int) throws {
        let fileSystem = MockFileSystem(homeDirectoryForCurrentUser: URL(filePath: "/User"), temporaryDirectory: URL(filePath: "/tmp"))
        fileSystem.item = ["/": ["User": [:], "tmp": [:]]]
        let url = URL(filePath: "/tmp/nestfile.yaml")
        let originalData = Data(input.utf8)
        try fileSystem.write(originalData, to: url)

        do {
            _ = try Nestfile.load(from: url.path(), fileSystem: fileSystem)
            Issue.record("Expected invalid YAML")
        } catch let error as NestfileDecodingError {
            guard case .invalidSyntax(let line, let column) = error else {
                Issue.record("Expected a YAML syntax location")
                return
            }
            #expect(line == expectedLine)
            #expect(1 <= column)
            #expect(error.localizedDescription == "Invalid YAML at line \(line), column \(column).")
            #expect(!String(reflecting: error).contains(secret))
        }
        #expect(try fileSystem.data(at: url) == originalData)
    }

    @Test(arguments: ["targets: FORMAT_SECRET", "nestPath: [FORMAT_SECRET]\ntargets: []"])
    func invalidFormatsDoNotExposeDecodedValues(input: String) throws {
        let fileSystem = MockFileSystem(homeDirectoryForCurrentUser: URL(filePath: "/User"), temporaryDirectory: URL(filePath: "/tmp"))
        fileSystem.item = ["/": ["User": [:], "tmp": [:]]]
        let url = URL(filePath: "/tmp/nestfile.yaml")
        try fileSystem.write(Data(input.utf8), to: url)

        #expect(throws: NestfileDecodingError.invalidFormat) {
            try Nestfile.load(from: url.path(), fileSystem: fileSystem)
        }
        #expect(!NestfileDecodingError.invalidFormat.localizedDescription.contains("FORMAT_SECRET"))
    }

    @Test
    func fileReadFailuresKeepTheirOriginalErrorType() {
        let fileSystem = MockFileSystem(homeDirectoryForCurrentUser: URL(filePath: "/User"), temporaryDirectory: URL(filePath: "/tmp"))

        #expect(throws: MockFileSystem.MockFileSystemError.fileNotFound) {
            try Nestfile.load(from: "/missing.yaml", fileSystem: fileSystem)
        }
    }
}
