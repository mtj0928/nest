import Foundation
import NestCLI
import NestKit
import Subprocess
import Testing

struct CommandLogTests {
    @Test(arguments: [false, true])
    func runHidesArgumentsAndPreservesPassthroughAndExitStatus(verbose: Bool) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(component: "nest-run-log-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let directory = NestDirectory(rootDirectory: root)
        let runnerURL = root.appending(components: "command-directory-secret", "runner")
        try fileManager.createDirectory(at: runnerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let capturedArgumentsURL = root.appending(component: "arguments.bin")
        let script = """
        #!/bin/sh
        read -r input
        [ "$input" = 'interactive-input' ] || exit 18
        printf '%s\\000' "$@" > "$ARGUMENT_CAPTURE_PATH"
        printf 'child-output-preserved'
        printf 'child-error-preserved' >&2
        exit 37
        """
        try Data(script.utf8).write(to: runnerURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runnerURL.path())
        let repositoryURL = try #require(URL(string: "https://github.com/owner/repo"))
        let repository = Repository(reference: .url(repositoryURL), version: "1.0.0")
        let command = NestInfo.Command(
            version: "1.0.0",
            binaryPath: directory.relativePath(runnerURL),
            resourcePaths: [],
            manufacturer: .localBuild(repository: repository)
        )
        let storedData = try JSONEncoder().encode(NestInfo(version: NestInfo.currentVersion, commands: ["runner": [command]]))
        try storedData.write(to: directory.infoJSON)
        let nestfileURL = root.appending(component: "nestfile.yaml")
        try Nestfile(nestPath: nil, targets: [
            .repository(Nestfile.Repository(reference: "owner/repo", version: "1.0.0", assetName: nil, checksum: nil))
        ]).write(to: nestfileURL.path(percentEncoded: false), fileSystem: fileManager)
        let passthrough = ["--token", "token-secret", "--password=password-secret", "positional-secret",
                           "https://url-user:url-password@example.com/tool.zip?signature=url-secret#fragment-secret", "value with spaces", "\nline-secret", ""]
        let executableURL = Bundle(for: TestBundleMarker.self).bundleURL
            .deletingLastPathComponent()
            .appending(component: "nest")
        let environment = [
            "NEST_PATH": root.path(percentEncoded: false),
            "PATH": "/usr/bin:/bin",
            "ARGUMENT_CAPTURE_PATH": capturedArgumentsURL.path(percentEncoded: false)
        ]
        let arguments = ["run"] + (verbose ? ["--verbose"] : [])
            + ["--no-install", "--nestfile-path", nestfileURL.path(percentEncoded: false), "owner/repo"] + passthrough
        let result = try await Subprocess.run(
            .path(.init(executableURL.path(percentEncoded: false))),
            arguments: .init(arguments),
            environment: .custom(environment.subprocessValues),
            input: .string("interactive-input\n"),
            output: .string(limit: 1024 * 1024),
            error: .combinedWithOutput
        )
        let output = result.standardOutput

        #expect(result.terminationStatus == .exited(37), "\(output)")
        #expect(output.contains("child-output-preserved"))
        #expect(output.contains("child-error-preserved"))
        #expect(output.contains("$ runner (argument count: 8)") == verbose)
        for secret in [
            "command-directory-secret", "token-secret", "password-secret", "positional-secret", "url-user",
            "url-password", "url-secret", "fragment-secret", "value with spaces", "line-secret"
        ] {
            #expect(!output.contains(secret), "\(output)")
        }
        #expect(try Data(contentsOf: capturedArgumentsURL) == Data(passthrough.map { $0 + "\0" }.joined().utf8))
        #expect(try Data(contentsOf: directory.infoJSON) == storedData)
    }

    @Test(arguments: ["install", "bootstrap"])
    func requiredChecksumErrorsDoNotExposeURLSecrets(command: String) async throws {
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
        let environment = ["NEST_PATH": root.path(percentEncoded: false), "PATH": "/usr/bin:/bin"]
        let arguments = if command == "install" {
            ["install", zipURL.absoluteString, "--checksum-policy", "require"]
        } else {
            ["bootstrap", nestfileURL.path(percentEncoded: false), "--checksum-policy", "require"]
        }
        let result = try await Subprocess.run(
            .path(.init(executableURL.path(percentEncoded: false))),
            arguments: .init(arguments),
            environment: .custom(environment.subprocessValues),
            output: .string(limit: 1024 * 1024),
            error: .combinedWithOutput
        )
        let output = result.standardOutput

        #expect(result.terminationStatus == .exited(1), "\(output)")
        #expect(output.contains("Missing checksum for \"https://downloads.example.com/foo.artifactbundle.zip\""))
        for secret in ["zip-user", "zip-password", "zip-secret", "zip-private", "signature="] {
            #expect(!output.contains(secret), "\(output)")
        }
        #expect(try Data(contentsOf: nestfileURL) == originalNestfileData)
    }

    @Test(arguments: ["install", "list", "switch", "bootstrap"])
    func installedArtifactCommandsDoNotExposeURLSecrets(command: String) async throws {
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
        let environment = ["NEST_PATH": root.path(percentEncoded: false), "PATH": "/usr/bin:/bin"]
        let arguments = switch command {
        case "install": ["install", zipURL.absoluteString, "--checksum-policy", "skip"]
        case "list": ["list", "--source"]
        case "switch": ["switch", "audit-tool"]
        case "bootstrap": ["bootstrap", nestfilePath, "--checksum-policy", "skip"]
        default: [String]()
        }
        let result = try await Subprocess.run(
            .path(.init(executableURL.path(percentEncoded: false))),
            arguments: .init(arguments),
            environment: .custom(environment.subprocessValues),
            input: .string(command == "switch" ? "1\n" : ""),
            output: .string(limit: 1024 * 1024),
            error: .combinedWithOutput
        )
        let output = result.standardOutput

        #expect(result.terminationStatus == .exited(0), "\(output)")
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
