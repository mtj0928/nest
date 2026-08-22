import Testing
@testable import NestKit

@Suite
struct GitHubRegistryConfigsTests {
    struct Fixture: CustomTestStringConvertible {
        let testDescription: String
        let registryTokenEnvironmentVariableNames: [String: String]
        let environmentVariables: [String: String?]
        let expectedTokens: [String: String?]
        let sourceLocation: SourceLocation

        init(
            _ testDescription: String,
            _ registryTokenEnvironmentVariableNames: [String: String],
            _ environmentVariables: [String: String?],
            _ expectedTokens: [String: String?],
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            self.testDescription = testDescription
            self.registryTokenEnvironmentVariableNames = registryTokenEnvironmentVariableNames
            self.environmentVariables = environmentVariables
            self.expectedTokens = expectedTokens
            self.sourceLocation = sourceLocation
        }
    }

    static let fixtures: [Fixture] = [
        .init(
            "Can resolve custom tokens",
            ["ghe.example.com": "MY_GHE_TOKEN"],
            ["MY_GHE_TOKEN": "my-ghe-token"],
            ["ghe.example.com": "my-ghe-token"]
        ),
        .init(
            "Cannot resolve unknown token",
            ["ghe.example.com": "MY_GHE_TOKEN"],
            ["MY_GHE_TOKEN": "my-ghe-token"],
            ["unknown.example.com": nil]
        ),
        .init(
            "Can resolve GitHub.com token only for GitHub.com",
            [:],
            ["GH_TOKEN": "github-com-token"],
            ["github.com": "github-com-token", "ghe.example.com": nil]
        ),
        .init(
            "Does not implicitly resolve custom host tokens from GHE_TOKEN",
            [:],
            ["GHE_TOKEN": "default-enterprise-token"],
            ["github.com": nil, "ghe.example.com": nil]
        ),
        .init(
            "Can explicitly associate GHE_TOKEN with one custom host",
            ["ghe.example.com": "GHE_TOKEN"],
            ["GHE_TOKEN": "enterprise-token"],
            ["ghe.example.com": "enterprise-token", "other.example.com": nil]
        ),
        .init(
            "Never sends GH_TOKEN to a custom host even when configured",
            ["ghe.example.com": "GH_TOKEN"],
            ["GH_TOKEN": "github-com-token"],
            ["github.com": "github-com-token", "ghe.example.com": nil]
        ),
        .init(
            "Can overwrite GitHub.com token by the configuration",
            ["github.com": "OVERWRITTEN_GH_TOKEN", "ghe.example.com": "MY_GHE_TOKEN"],
            ["MY_GHE_TOKEN": "my-ghe-token", "GH_TOKEN": "github-com-token", "OVERWRITTEN_GH_TOKEN": "overwritten-github-com-token"],
            ["github.com": "overwritten-github-com-token", "ghe.example.com": "my-ghe-token"]
        ),
    ]

    @Test(arguments: fixtures)
    func resolve(fixture: Fixture) async throws {
        let environmentVariables = TestingEnvironmentVariables(environmentVariables: fixture.environmentVariables)
        let configs = GitHubRegistryConfigs.resolve(
            environmentVariableNames: fixture.registryTokenEnvironmentVariableNames,
            environmentVariablesStorage: environmentVariables
        )
        for (host, expectedToken) in fixture.expectedTokens {
            let resolvedToken = configs.config(for: GitHubRegistryConfigs.Host(host))?.token
            #expect(resolvedToken == expectedToken, "\(fixture.testDescription)", sourceLocation: fixture.sourceLocation)
        }
    }

    @Test
    func protectedTokenEnvironmentVariableNamesIncludeGitHubDefaultAndConfiguredNames() {
        let configs = GitHubRegistryConfigs.resolve(
            environmentVariableNames: [
                "github.com": "CUSTOM_GITHUB_TOKEN",
                "ghe.example.com": "ENTERPRISE_TOKEN"
            ],
            environmentVariablesStorage: TestingEnvironmentVariables(environmentVariables: [:])
        )

        #expect(configs.protectedTokenEnvironmentVariableNames == [
            "GH_TOKEN",
            "CUSTOM_GITHUB_TOKEN",
            "ENTERPRISE_TOKEN"
        ])
    }
}
