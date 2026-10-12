import Foundation
import HTTPTypes
import HTTPTypesFoundation
import Logging
import NestCLI
import NestKit
import NestTestHelpers
import Testing
import os

struct ArtifactBundleFetcherLogTests {
    @Test(arguments: [Logging.Logger.Level.info, .trace])
    func directAndAPIResolvedDownloadsAndWarningsKeepSecretsOutOfLogs(logLevel: Logging.Logger.Level) async throws {
        let fileSystem = MockFileSystem(homeDirectoryForCurrentUser: URL(filePath: "/User"), temporaryDirectory: URL(filePath: "/tmp"))
        fileSystem.item = ["/": ["User": [:], "tmp": [:]]]
        let recorder = LogRecorder()
        let logger = recorder.makeLogger(logLevel: logLevel)
        let client = MockHTTPClient(mockFileSystem: fileSystem, logger: logger)
        let zipURL = try #require(URL(string: "https://zip-user:zip-password@downloads.example.com/foo.artifactbundle.zip?signature=zip-secret#zip-private"))
        let downloadRequestURL = try #require(HTTPRequest(url: zipURL).url)
        let apiURL = try #require(URL(string: "https://api.github.com/repos/owner/repo/releases/tags/1.0.0"))
        let response = """
        {
            "tag_name": "1.0.0",
            "assets": [{
                "name": "foo.artifactbundle.zip",
                "browser_download_url": "\(zipURL.absoluteString)"
            }]
        }
        """
        client.dummyData = [
            downloadRequestURL: try Data(contentsOf: artifactBundlePath),
            apiURL: Data(response.utf8)
        ]
        let executorBuilder = MockExecutorBuilder { command, arguments in
            if command == "/usr/bin/which", arguments == ["swift"] {
                return "/usr/bin/swift"
            }
            if command == "/usr/bin/swift", arguments == ["-print-target-info"] {
                return "{\"target\":{\"unversionedTriple\":\"arm64-apple-macosx\"}}"
            }
            if command == "/usr/bin/swift", arguments.count == 3,
               arguments[0] == "package", arguments[1] == "compute-checksum" {
                return "aaa"
            }
            Issue.record("Unexpected command: \(command)")
            return ""
        }
        let fetcher = ArtifactBundleFetcher(
            workingDirectory: URL(filePath: "/tmp/nest"),
            executorBuilder: executorBuilder,
            fileSystem: fileSystem,
            fileDownloader: NestFileDownloader(httpClient: client),
            nestInfoController: NestInfoController(directory: NestDirectory(rootDirectory: URL(filePath: "/User/.nest")), fileSystem: fileSystem),
            assetRegistryClientBuilder: AssetRegistryClientBuilder(httpClient: client, registryConfigs: nil, logger: logger),
            artifactBundleZIPCacheOption: .disableCache,
            logger: logger
        )

        let checksumOption = ChecksumOption.warnOnMissingChecksum(target: zipURL.absoluteString)
        let directBinaries = try await fetcher.downloadArtifactBundle(url: zipURL, checksum: checksumOption)
        let repositoryURL = try #require(URL(string: "https://github.com/owner/repo"))
        let resolvedBinaries = try await fetcher.fetchArtifactBundleFromGitRepository(
            for: repositoryURL,
            version: .tag("1.0.0"),
            artifactBundleZipFileName: nil,
            checksum: checksumOption
        )

        #expect(directBinaries.count == 1)
        #expect(resolvedBinaries.count == 1)
        for binary in directBinaries + resolvedBinaries {
            guard case .artifactBundle(let sourceInfo) = binary.manufacturer else {
                Issue.record("Expected an artifact bundle")
                continue
            }
            #expect(sourceInfo.zipURL == zipURL)
        }
        let logs = recorder.messages.joined(separator: "\n")
        for secret in ["zip-user", "zip-password", "zip-secret", "zip-private", "signature="] {
            #expect(!logs.contains(secret))
        }
        let downloads = recorder.messages.filter { $0.contains("Downloading the artifact bundle ZIP") }
        #expect(downloads.count == 2)
        #expect(downloads.allSatisfy { $0.contains("https://downloads.example.com/foo.artifactbundle.zip") })
        let warnings = recorder.messages.filter { $0.contains("CHECKSUM MISSING") }
        #expect(warnings.count == 2)
        #expect(warnings.allSatisfy { $0.contains("nest is installing \"https://downloads.example.com/foo.artifactbundle.zip\"") })
        #expect(warnings.allSatisfy { $0.contains("checksum: aaa") })
    }
}

private final class LogRecorder: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [String]())

    var messages: [String] {
        storage.withLock { $0 }
    }

    func makeLogger(logLevel: Logging.Logger.Level) -> Logging.Logger {
        var logger = Logging.Logger(label: "Test") { _ in Handler(recorder: self) }
        logger.logLevel = logLevel
        return logger
    }

    private func record(_ message: String) {
        storage.withLock { $0.append(message) }
    }
}

extension LogRecorder {
    private struct Handler: LogHandler {
        var metadata = Logging.Logger.Metadata()
        var logLevel = Logging.Logger.Level.info
        let recorder: LogRecorder

        subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
            get { metadata[key] }
            set { metadata[key] = newValue }
        }

        func log(
            level: Logging.Logger.Level,
            message: Logging.Logger.Message,
            metadata: Logging.Logger.Metadata?,
            source: String,
            file: String,
            function: String,
            line: UInt
        ) {
            recorder.record(message.description)
        }
    }
}
