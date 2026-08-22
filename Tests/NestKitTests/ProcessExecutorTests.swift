import Logging
import Testing
@testable import NestKit

struct ProcessExecutorTests {
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
