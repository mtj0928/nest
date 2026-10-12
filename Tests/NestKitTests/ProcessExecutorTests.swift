import Logging
import Testing
@testable import NestKit

struct ProcessExecutorTests {
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
