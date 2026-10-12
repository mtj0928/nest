import Foundation
import NestCLI
import NestKit
import Testing

struct CommandLogTests {
    @Test(arguments: ["install", "bootstrap"])
    func requiredChecksumErrorsDoNotExposeURLSecrets(command: String) throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(component: "nest-checksum-log-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let zipURL = try #require(URL(string: "https://zip-user:zip-password@downloads.example.com/foo.artifactbundle.zip?signature=zip-secret#zip-private"))
        try #require(zipURL.needsUnzip)
        let nestfileURL = root.appending(component: "nestfile.yaml")
        try Nestfile(nestPath: nil, targets: [.zip(Nestfile.ZIPURL(zipURL: zipURL.absoluteString, checksum: nil))])
            .write(to: nestfileURL.path(percentEncoded: false), fileSystem: fileManager)
        let originalNestfileData = try Data(contentsOf: nestfileURL)
        let executableURL = Bundle(for: TestBundleMarker.self).bundleURL
            .deletingLastPathComponent()
            .appending(component: "nest")
        let process = Process()
        process.executableURL = executableURL
        process.environment = ["NEST_PATH": root.path(percentEncoded: false), "PATH": "/usr/bin:/bin"]
        process.arguments = if command == "install" {
            ["install", zipURL.absoluteString, "--checksum-policy", "require"]
        } else {
            ["bootstrap", nestfileURL.path(percentEncoded: false), "--checksum-policy", "require"]
        }
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = try #require(String(data: outputData, encoding: .utf8))

        #expect(process.terminationStatus == 1, "\(output)")
        #expect(output.contains("Missing checksum for \"https://downloads.example.com/foo.artifactbundle.zip\""))
        for secret in ["zip-user", "zip-password", "zip-secret", "zip-private", "signature="] {
            #expect(!output.contains(secret), "\(output)")
        }
        #expect(try Data(contentsOf: nestfileURL) == originalNestfileData)
    }

    @Test(arguments: ["install", "list", "switch", "bootstrap"])
    func installedArtifactCommandsDoNotExposeURLSecrets(command: String) throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(component: "nest-command-log-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let directory = NestDirectory(rootDirectory: root)
        let zipURL = try #require(URL(string: "https://zip-user:zip-password@downloads.example.com/foo.artifactbundle.zip?signature=zip-secret#zip-private"))
        let otherZipURL = try #require(URL(string: "https://zip-user:zip-password@downloads.example.com/bar.artifactbundle.zip?signature=zip-secret#zip-private"))
        var installedCommands = [NestInfo.Command]()
        for (url, version) in [(zipURL, "1.0.0"), (otherZipURL, "2.0.0")] {
            let manufacturer = ExecutableManufacturer.artifactBundle(sourceInfo: ArtifactBundleSourceInfo(zipURL: url, repository: nil))
            let binary = ExecutableBinary(commandName: "audit-tool", binaryPath: root, version: version, manufacturer: manufacturer)
            let binaryPath = directory.binaryPath(of: binary)
            try fileManager.createDirectory(at: binaryPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: binaryPath)
            installedCommands.append(NestInfo.Command(
                version: version,
                binaryPath: directory.relativePath(binaryPath),
                resourcePaths: [],
                manufacturer: manufacturer
            ))
        }
        let info = NestInfo(version: NestInfo.currentVersion, commands: ["audit-tool": installedCommands])
        let storedData = try JSONEncoder().encode(info)
        try storedData.write(to: directory.infoJSON)
        let nestfilePath = root.appending(component: "nestfile.yaml").path(percentEncoded: false)
        try Nestfile(nestPath: nil, targets: [.zip(Nestfile.ZIPURL(zipURL: zipURL.absoluteString, checksum: nil))])
            .write(to: nestfilePath, fileSystem: fileManager)

        let executableURL = Bundle(for: TestBundleMarker.self).bundleURL
            .deletingLastPathComponent()
            .appending(component: "nest")
        #expect(fileManager.fileExists(atPath: executableURL.path()))
        let process = Process()
        process.executableURL = executableURL
        process.environment = ["NEST_PATH": root.path(percentEncoded: false), "PATH": "/usr/bin:/bin"]
        process.arguments = switch command {
        case "install": ["install", zipURL.absoluteString, "--checksum-policy", "skip"]
        case "list": ["list", "--source"]
        case "switch": ["switch", "audit-tool"]
        case "bootstrap": ["bootstrap", nestfilePath, "--checksum-policy", "skip"]
        default: []
        }
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        try process.run()
        if command == "switch" {
            try inputPipe.fileHandleForWriting.write(contentsOf: Data("1\n".utf8))
        }
        try inputPipe.fileHandleForWriting.close()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = try #require(String(data: outputData, encoding: .utf8))

        #expect(process.terminationStatus == 0, "\(output)")
        for secret in ["zip-user", "zip-password", "zip-secret", "zip-private", "signature=", "ExecutableBinary("] {
            #expect(!output.contains(secret), "\(output)")
        }
        if command == "install" {
            #expect(output.contains("Skip to install audit-tool version 1.0.0"))
        } else {
            #expect(output.contains("https://downloads.example.com/foo.artifactbundle.zip"))
        }
        #expect(try Data(contentsOf: directory.infoJSON) == storedData)
    }
}

private final class TestBundleMarker: NSObject {}
