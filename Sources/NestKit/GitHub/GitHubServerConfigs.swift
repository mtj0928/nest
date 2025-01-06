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
    /// An enum value to represent GitHub sever host
    public enum Host: Hashable, Sendable {
        /// A value indicates github.com
        case githubCom

        /// A value indicates an GitHub Enterprise Server
        case custom(String)

        init(_ host: String) {
            switch host {
            case "github.com": self = .githubCom
            default: self = .custom(host)
            }
        }

    }

    struct Config : Sendable {
        var token: String
    }

    /// Resolve server configurations from environment variable names.
    /// @params environmentVariableNames A dictionary of environment variable names with hostname as key.
    /// @params environmentVariables A container of Environment Variables.
    /// @return A new server configuration.
    public static func resolve(
        environmentVariableNames: [String: String],
        environmentVariables: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()
    ) -> GitHubServerConfigs {
        let servers: [Host: Config] = environmentVariableNames.reduce(into: [:]) { (servers, pair) in
            let (host, environmentVariableName) = pair
            if let token = environmentVariables[environmentVariableName] {
                let host = Host(host)
                servers[host] = Config(token: token)
            }
        }
        return .init(servers: servers)
    }

    private var servers: [Host: Config]

    private init(servers: [Host: Config]) {
        self.servers = servers
    }

    /// Get the server configuration for URL. It will be resolved from its host.
    func config(for url: URL, environmentVariables: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()) -> Config? {
        if let hostString = url.host() {
            return servers[Host(hostString)]
        }
        return nil
    }
}
