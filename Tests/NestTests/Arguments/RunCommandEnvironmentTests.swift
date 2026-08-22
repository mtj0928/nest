import Testing
@testable import nest
@testable import NestKit

struct RunCommandEnvironmentTests {
    @Test
    func configurationCarriesRegistryTokenEnvironmentVariableNamesToRunLayer() {
        let configuration = NestKit.Configuration.make(
            nestPath: nil,
            registryTokenEnvironmentVariableNames: [
                "github.com": "CUSTOM_GITHUB_TOKEN",
                "ghe.example.com": "CUSTOM_ENTERPRISE_TOKEN"
            ],
            logLevel: .info,
            enableUserScopeCache: false
        )

        #expect(configuration.registryTokenEnvironmentVariableNames == [
            "GH_TOKEN",
            "CUSTOM_GITHUB_TOKEN",
            "CUSTOM_ENTERPRISE_TOKEN"
        ])
    }
}
