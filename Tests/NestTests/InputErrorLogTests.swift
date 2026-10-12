import Foundation
import Testing

struct InputErrorLogTests {
    @Test(arguments: ["bootstrap", "update-nestfile", "resolve-nestfile", "run"])
    func malformedNestfilesDoNotExposeTheirContents(command: String) throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(component: "nest-input-log-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let url = root.appending(component: "nestfile.yaml")
        let originalData = Data("targets: [https://example.com/tool.zip?token=YAML_SECRET, }".utf8)
        try originalData.write(to: url)
        let process = Process()
        process.executableURL = Bundle(for: InputTestBundleMarker.self).bundleURL
            .deletingLastPathComponent().appending(component: "nest")
        process.arguments = if command == "run" {
            ["run", "--nestfile-path", url.path(percentEncoded: false), "owner/repo"]
        } else {
            [command, url.path(percentEncoded: false)]
        }
        process.environment = ["NEST_PATH": root.path(percentEncoded: false), "PATH": "/usr/bin:/bin"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = try #require(String(data: outputData, encoding: .utf8))

        #expect(process.terminationStatus == (command == "run" ? 0 : 1), "\(output)")
        #expect(output.contains("Invalid YAML at line 1, column"))
        #expect(!output.contains("YAML_SECRET"))
        #expect(!output.contains("targets:"))
        #expect(try Data(contentsOf: url) == originalData)
    }

    @Test(arguments: ["bootstrapInvalid", "runInvalid", "runMissingVersion", "runMissingFile"])
    func invalidTargetsAndReadFailuresDoNotEchoInputs(scenario: String) throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(component: "nest-invalid-target-log-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let url = root.appending(component: "nestfile.yaml")
        let contents = scenario == "bootstrapInvalid" ? "targets:\n  - reference: TARGET_SECRET\n" : "targets: []\n"
        try Data(contents.utf8).write(to: url)
        let process = Process()
        process.executableURL = Bundle(for: InputTestBundleMarker.self).bundleURL
            .deletingLastPathComponent().appending(component: "nest")
        process.arguments = switch scenario {
        case "bootstrapInvalid": ["bootstrap", url.path(percentEncoded: false)]
        case "runInvalid": ["run", "--nestfile-path", url.path(percentEncoded: false), "TARGET_SECRET"]
        case "runMissingVersion": ["run", "--nestfile-path", url.path(percentEncoded: false), "https://target-user:target-password@ghe.example.com/owner/repo?token=TARGET_SECRET"]
        default: ["run", "--nestfile-path", root.appending(component: "TARGET_SECRET.yaml").path(percentEncoded: false), "owner/repo"]
        }
        process.environment = ["NEST_PATH": root.path(percentEncoded: false), "PATH": "/usr/bin:/bin"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = try #require(String(data: outputData, encoding: .utf8))

        #expect(process.terminationStatus == 0, "\(output)")
        for secret in ["TARGET_SECRET", "target-user", "target-password", "token="] {
            #expect(!output.contains(secret), "\(output)")
        }
        switch scenario {
        case "bootstrapInvalid": #expect(output.contains("Invalid target at index 1"))
        case "runInvalid": #expect(output.contains("Invalid repository reference"))
        case "runMissingVersion": #expect(output.contains("Failed to find a matching repository with a specified version"))
        default: #expect(output.contains("Failed to read nestfile. Check --nestfile-path."))
        }
    }
}

private final class InputTestBundleMarker: NSObject {}
