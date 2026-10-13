import Darwin
import Foundation
import Logging
import Testing
@testable import NestKit

struct ProcessExecutorTests {
    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func cancellationTerminatesRunningCommand(interactive: Bool) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(component: "nest-cancellation-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let processIDURL = root.appending(component: "process-id")
        let executor = NestProcessExecutor(environment: [:], logger: Logger(label: "Test"))
        let task = Task {
            let script = "printf '%s' \"$$\" > \"$1\"; exec /bin/sleep 30"
            let arguments = ["-c", script, "runner", processIDURL.path(percentEncoded: false)]
            if interactive {
                _ = try await executor.executeInteractively(command: "/bin/sh", arguments)
            } else {
                _ = try await executor.execute(command: "/bin/sh", arguments)
            }
        }
        defer { task.cancel() }
        let clock = ContinuousClock()
        let startDeadline = clock.now.advanced(by: .seconds(5))
        while !fileManager.fileExists(atPath: processIDURL.path(percentEncoded: false)), clock.now < startDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let processIDText = try String(contentsOf: processIDURL, encoding: .utf8)
        let processID = try #require(Int32(processIDText))

        let cancellationTime = clock.now
        task.cancel()
        _ = await task.result

        #expect(cancellationTime.duration(to: clock.now) < .seconds(5))
        #expect(kill(processID, 0) == -1)
        #expect(errno == ESRCH)
    }

    @Test(arguments: [
        "",
        "  first line\n\n  second line\r\nthird\rfourth\u{2028}fifth  \n",
        String(repeating: "あ", count: 50_000)
    ])
    func collectsCompleteOutputAndPreservesInternalWhitespace(text: String) async throws {
        let recorder = TestLogRecorder()
        let executor = NestProcessExecutor(environment: [:], logger: recorder.makeLogger(logLevel: .trace))
        let script = """
        printf '%s' "$1"
        printf 'stderr-finished' >&2
        """

        let output = try await executor.execute(command: "/bin/sh", "-c", script, "runner", text)

        #expect(output == text.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(recorder.messages.contains("stderr-finished"))
    }

    @Test
    func drainsBothStreamsBeforeReturning() async throws {
        let recorder = TestLogRecorder()
        let executor = NestProcessExecutor(environment: [:], logger: recorder.makeLogger(logLevel: .trace))
        let script = """
        index=0
        while [ "$index" -lt 10000 ]; do
            printf 'standard-output-line\n'
            printf 'standard-error-line\n' >&2
            index=$((index + 1))
        done
        printf 'output-finished'
        printf 'error-finished' >&2
        """

        let output = try await executor.execute(command: "/bin/sh", "-c", script)

        #expect(output == String(repeating: "standard-output-line\n", count: 10_000) + "output-finished")
        #expect(recorder.messages.filter { $0 == "standard-error-line" }.count == 10_000)
        #expect(recorder.messages.contains("error-finished"))
    }

    @Test
    func decodesUTF8SplitAcrossWrites() async throws {
        let recorder = TestLogRecorder()
        let executor = NestProcessExecutor(environment: [:], logger: recorder.makeLogger(logLevel: .trace))
        let script = """
        printf '\\343'
        /bin/sleep 0.02
        printf '\\201\\202'
        """

        let output = try await executor.execute(command: "/bin/sh", "-c", script)

        #expect(output == "あ")
        #expect(recorder.messages.contains("あ"))
    }

    @Test(arguments: [false, true])
    func appliesWorkingDirectoryAndFilteredEnvironment(interactive: Bool) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(component: "nest process-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let executor = NestProcessExecutor(
            currentDirectory: root,
            environment: ["PRESERVED": "value", "GH_TOKEN": "removed"],
            removingEnvironmentVariables: ["GH_TOKEN"],
            logger: Logger(label: "Test")
        )
        let script = """
        [ "$PWD" -ef "$1" ] &&
        [ "$PRESERVED" = 'value' ] &&
        [ "${GH_TOKEN-unset}" = 'unset' ] &&
        [ "${HOME-unset}" = 'unset' ] || exit 17
        """
        let arguments = ["-c", script, "runner", root.resolvingSymlinksInPath().path(percentEncoded: false)]

        if interactive {
            let status = try await executor.executeInteractively(command: "/bin/sh", arguments)
            #expect(status == 0)
        } else {
            let output = try await executor.execute(command: "/bin/sh", arguments)
            #expect(output.isEmpty)
        }
    }

    @Test(arguments: ["exit 37", "kill -TERM $$"])
    func rejectsUnsuccessfulCommandsAfterLoggingOutput(script: String) async {
        let recorder = TestLogRecorder()
        let executor = NestProcessExecutor(environment: [:], logger: recorder.makeLogger(logLevel: .trace))

        await #expect(throws: (any Error).self) {
            try await executor.execute(command: "/bin/sh", "-c", "printf 'failure-details' >&2; " + script)
        }

        #expect(recorder.messages.contains("failure-details"))
    }

    @Test(arguments: [("exit 0", Int32(0)), ("exit 37", Int32(37)), ("kill -TERM $$", Int32(15))])
    func returnsInteractiveExitStatus(script: String, expectedStatus: Int32) async throws {
        let executor = NestProcessExecutor(environment: [:], logger: Logger(label: "Test"))

        let status = try await executor.executeInteractively(command: "/bin/sh", "-c", script)

        #expect(status == expectedStatus)
    }

    @Test(arguments: [false, true])
    func rejectsMissingExecutables(interactive: Bool) async {
        let executor = NestProcessExecutor(environment: [:], logger: Logger(label: "Test"))
        let command = "/nonexistent-nest-executable-\(UUID().uuidString)"

        await #expect(throws: (any Error).self) {
            if interactive {
                _ = try await executor.executeInteractively(command: command, [])
            } else {
                _ = try await executor.execute(command: command, [])
            }
        }
    }

    @Test(arguments: [false, true])
    func executeHidesArgumentsWhilePreservingTheirValues(hasArguments: Bool) async throws {
        let script = """
        [ "$#" -eq 6 ] &&
        [ "$1" = '--token' ] &&
        [ "$2" = 'token-secret' ] &&
        [ "$3" = '--password=password-secret' ] &&
        [ "$4" = 'https://url-user:url-password@example.com/tool.zip?signature=url-secret#fragment-secret' ] &&
        [ "$5" = 'value with spaces' ] &&
        [ "$6" = '' ] || exit 17
        printf 'arguments-preserved'
        printf 'stderr-preserved' >&2
        """
        let arguments = if hasArguments {
            ["-c", script, "runner", "--token", "token-secret", "--password=password-secret",
             "https://url-user:url-password@example.com/tool.zip?signature=url-secret#fragment-secret", "value with spaces", ""]
        } else {
            [String]()
        }
        let recorder = TestLogRecorder()
        let executor = NestProcessExecutor(environment: [:], logger: recorder.makeLogger(logLevel: .trace))

        let output = try await executor.execute(command: hasArguments ? "/bin/sh" : "/usr/bin/true", arguments)

        let commandLogs = recorder.messages.filter { $0.hasPrefix("$ ") }
        #expect(commandLogs == [hasArguments ? "$ sh (argument count: 9)" : "$ true (argument count: 0)"])
        #expect(output == (hasArguments ? "arguments-preserved" : ""))
        if hasArguments {
            #expect(recorder.messages.contains("stderr-preserved"))
        }
        let logs = recorder.messages.joined(separator: "\n")
        for secret in ["token-secret", "password-secret", "url-user", "url-password", "url-secret", "fragment-secret", "value with spaces"] {
            #expect(!logs.contains(secret))
        }
    }

    @Test
    func removesOnlySpecifiedEnvironmentVariables() {
        let executor = NestProcessExecutor(
            environment: [
                "GH_TOKEN": "github-token",
                "GHE_TOKEN": "enterprise-token",
                "CUSTOM_REGISTRY_TOKEN": "custom-token",
                "ORDINARY_VARIABLE": "preserved"
            ],
            removingEnvironmentVariables: [
                "GH_TOKEN",
                "CUSTOM_REGISTRY_TOKEN"
            ],
            logger: Logger(label: "Test")
        )

        #expect(executor.environment == [
            "GHE_TOKEN": "enterprise-token",
            "ORDINARY_VARIABLE": "preserved"
        ])
    }
}
