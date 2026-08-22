import Foundation

public protocol EnvironmentVariableStorage {
    subscript(_ key: String) -> String? { get }
}

public struct SystemEnvironmentVariableStorage: EnvironmentVariableStorage {
    public subscript(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }

    public init() { }
}

public struct RegistryConfigs: Sendable {
    public var github: GitHubRegistryConfigs?

    public init(github: GitHubRegistryConfigs?) {
        self.github = github
    }
}

/// A container of GitHub server configurations.
public struct GitHubRegistryConfigs: Sendable {
    /// An enum value to represent GitHub sever host.
    public enum Host: Hashable, Sendable {
        /// A value indicates github.com
        case githubCom

        /// A value indicates an GitHub Enterprise Server.
        case custom(String)

        init(_ host: String) {
            let normalizedHost = host.lowercased()
            self = normalizedHost == "github.com" ? .githubCom : .custom(normalizedHost)
        }

        var hostname: String {
            switch self {
            case .githubCom: "github.com"
            case .custom(let hostname): hostname
            }
        }
    }

    /// A struct to contain the server configuration.
    struct Config: Sendable {
        /// Where the token come from.
        var environmentVariable: String
        /// GitHub API token.
        var token: String
    }

    public typealias GitHubServerHostName = String
    public typealias EnvironmentVariableName = String

    /// Environment variables that must not be inherited by executables launched through `nest run`.
    public let protectedTokenEnvironmentVariableNames: Set<String>

    /// Resolve server configurations from environment variable names.
    ///
    /// `GH_TOKEN` is resolved only for GitHub.com. A custom host receives a token only when
    /// `environmentVariableNames` explicitly associates that host with an environment variable.
    ///
    /// - Parameters:
    ///   - environmentVariableNames: Environment variable names keyed by GitHub server hostname.
    ///   - environmentVariablesStorage: A container of environment variables.
    /// - Returns: A new server configuration.
    public static func resolve(
        environmentVariableNames: [GitHubServerHostName: EnvironmentVariableName],
        environmentVariablesStorage: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()
    ) -> GitHubRegistryConfigs {
        var loadedConfigs = [Host: Config]()
        if let config = Config(
            environmentVariableName: githubTokenEnvironmentVariableName,
            environmentVariablesStorage: environmentVariablesStorage
        ) {
            loadedConfigs[.githubCom] = config
        }

        environmentVariableNames.forEach { pair in
            let (host, environmentVariableName) = pair
            let registryHost = Host(host)
            if case .custom = registryHost,
               environmentVariableName == githubTokenEnvironmentVariableName {
                return
            }
            if let config = Config(
                environmentVariableName: environmentVariableName,
                environmentVariablesStorage: environmentVariablesStorage
            ) {
                loadedConfigs[registryHost] = config
            }
        }

        let protectedTokenEnvironmentVariableNames = Set(environmentVariableNames.values)
            .union([githubTokenEnvironmentVariableName])
        return .init(
            registries: loadedConfigs,
            protectedTokenEnvironmentVariableNames: protectedTokenEnvironmentVariableNames
        )
    }

    private static let githubTokenEnvironmentVariableName = "GH_TOKEN"
    private var registries: [Host: Config]

    private init(registries: [Host: Config], protectedTokenEnvironmentVariableNames: Set<String>) {
        self.registries = registries
        self.protectedTokenEnvironmentVariableNames = protectedTokenEnvironmentVariableNames
    }

    func config(for host: Host) -> Config? {
        registries[host]
    }
}

extension GitHubRegistryConfigs.Config {
    fileprivate init?(environmentVariableName: String, environmentVariablesStorage: some EnvironmentVariableStorage) {
        guard let environmentVariableValue = environmentVariablesStorage[environmentVariableName],
              !environmentVariableValue.isEmpty
        else {
            return nil
        }
        self.environmentVariable = environmentVariableName
        self.token = environmentVariableValue
    }
}
