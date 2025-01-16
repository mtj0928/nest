@testable import NestKit
import Foundation
import Testing

@Suite
struct GitHubServerConfigsTests {
    struct Fixture: CustomTestStringConvertible {
        let testDescription: String
        let registryTokenEnvironmentVariableNames: [String: String]
        let environmentVariables: [String: String?]
        let expectedTokens: [String: String?]
        let sourceLocation: SourceLocation

        init(_ testDescription: String, _ registryTokenEnvironmentVariableNames: [String : String], _ environmentVariables: [String : String?], _ expectedTokens: [String : String?], sourceLocation: SourceLocation = #_sourceLocation) {
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
            "Cannot resolve GitHub.com token",
            ["ghe.example.com": "MY_GHE_TOKEN"],
            ["MY_GHE_TOKEN": "my-ghe-token"],
            ["github.com": nil]
        ),
        .init(
            "Can resolve any GitHub registry tokens from `GHE_TOKEN`",
            [:],
            ["GHE_TOKEN": "default-enterprise-token"],
            ["github.com": nil, "ghe.example.com": "default-enterprise-token"]
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
        let configs = GitHubServerConfigs.resolve(
            environmentVariableNames: fixture.registryTokenEnvironmentVariableNames,
            environmentVariablesStorage: environmentVariables
        )
        for (host, expectedToken) in fixture.expectedTokens {
            let url = try #require(makeURL(from: host))
            let resolvedToken = configs.config(for: url, environmentVariablesStorage: environmentVariables)?.token
            #expect(resolvedToken == expectedToken, "\(fixture.testDescription)", sourceLocation: fixture.sourceLocation)
        }
    }

    private func makeURL(from host: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        return components.url
    }
}
