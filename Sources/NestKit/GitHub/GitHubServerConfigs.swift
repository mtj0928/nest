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

/// A container of GitHub server configurations.
public struct GitHubServerConfigs: Sendable {
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

    /// Resolve server configurations from environment variable names.
    /// If GH_TOKEN environment variable is set, the token for GitHub.com will be that.
    /// If other values are set on environmentVariableNames, the value will be overwritten.
    /// - Parameters environmentVariableNames A dictionary of environment variable names with hostname as key.
    /// - Parameters environmentVariables A container of environment variables.
    /// - Returns A new server configuration.
    public static func resolve(
        environmentVariableNames: [String: String],
        environmentVariables: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()
    ) -> GitHubServerConfigs {
        let loadedConfigs: [Host: Config] = environmentVariableNames.reduce(into: [:]) { (servers, pair) in
            let (host, environmentVariableName) = pair
            if let token = environmentVariables[environmentVariableName] {
                let host = Host(host)
                servers[host] = Config(environmentVariable: environmentVariableName, token: token)
            }
        }
        return .init(servers: loadedConfigs)
    }

    private var servers: [Host: Config]

    private init(servers: [Host: Config]) {
        self.servers = servers
    }

    /// Get the server configuration for URL. It will be resolved from its host.
    /// - Parameters url An URL.
    /// - Parameters environmentVariables A container of environment variables.
    /// - Returns A config for the host.
    func config(for url: URL, environmentVariables: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()) -> Config? {
        let defaultEnvironmentVariableName = "GH_TOKEN"
        if let hostString = url.host(), let configuredToken = servers[Host(hostString)] {
            return configuredToken
        } else if let defaultToken = environmentVariables[defaultEnvironmentVariableName] {
            return Config(environmentVariable: defaultEnvironmentVariableName, token: defaultToken)
        }
        return nil
    }
}
