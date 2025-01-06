import Foundation

public protocol EnvironmentVariableStorage {
    subscript(_ key: String) -> String? { get }
}

struct SystemEnvironmentVariableStorage: EnvironmentVariableStorage {
    subscript(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}

public struct GitHubServerConfigs: Sendable {
    public static let `default`: Self = .init(servers: [])

    public struct Config: Sendable {
        var host: String
        var tokenEnvironmentVariableName: String
    }
    private var servers: [Config]

    public init(servers: [Config]) {
        self.servers = servers
    }

    func resolveToken(for url: URL, environmentVariables: any EnvironmentVariableStorage = SystemEnvironmentVariableStorage()) -> String? {
        if let host = url.host(), let name = resolveEnvironmentVariable(for: host) {
            return environmentVariables[name]
        }
        return nil
    }

    private func resolveEnvironmentVariable(for host: String) -> String? {
        servers.first { $0.host == host }?.tokenEnvironmentVariableName
    }
}
