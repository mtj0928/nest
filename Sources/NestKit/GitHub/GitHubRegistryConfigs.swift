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
            switch host {
            case "github.com": self = .githubCom
            default: self = .custom(host)
            }
        }

    }

    /// A struct to contain the server configuration.
    struct Config : Sendable {
        /// Where the token come from.
        var environmentVariable: String
        /// GitHub API token.
        var token: String
    }

    public typealias GitHubServerHostName = String
    public typealias EnvironmentVariableName = String

    /// Resolve server configurations from environment variable names.
    /// If GH_TOKEN environment variable is set, the token for GitHub.com will be that.
    /// If other values are set on environmentVariableNames, the value will be overwritten.
    /// - Parameters environmentVariableNames A dictionary of environment variable names with hostname as key.
    /// - Parameters environmentVariablesStorage A container of environment variables.
    /// - Returns A new server configuration.
    public static func resolve(
        environmentVariableNames: [GitHubServerHostName: EnvironmentVariableName],
        environmentVariablesStorage: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()
    ) -> GitHubRegistryConfigs {
        let loadedConfigs: [Host: Config] = environmentVariableNames.reduce(into: [:]) { (registries, pair) in
            let (host, environmentVariableName) = pair
            if let token = environmentVariablesStorage[environmentVariableName] {
                let host = Host(host)
                registries[host] = Config(environmentVariable: environmentVariableName, token: token)
            }
        }
        return .init(registries: loadedConfigs)
    }

    private var registries: [Host: Config]

    private init(registries: [Host: Config]) {
        self.registries = registries
    }

    /// Get the server configuration for URL. It will be resolved from its host.
    /// - Parameters url An URL.
    /// - Parameters environmentVariablesStorage A container of environment variables.
    /// - Returns A config for the host.
    func config(for url: URL, environmentVariablesStorage: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()) -> Config? {
        guard let hostString = url.host() else {
            return nil
        }
        let host = Host(hostString)
        switch host {
        case .githubCom:
            return registries[host] ?? Config(environmentVariableName: "GH_TOKEN", environmentVariablesStorage: environmentVariablesStorage)
        case .custom:
            return registries[host] ?? Config(environmentVariableName: "GHE_TOKEN", environmentVariablesStorage: environmentVariablesStorage)
        }
    }
}

extension GitHubRegistryConfigs.Config {
    fileprivate init?(environmentVariableName: String, environmentVariablesStorage: some EnvironmentVariableStorage) {
        if let environmentVariableValue = environmentVariablesStorage[environmentVariableName] {
            self.environmentVariable = environmentVariableName
            self.token = environmentVariableValue
        } else {
            return nil
        }   
    }
}
