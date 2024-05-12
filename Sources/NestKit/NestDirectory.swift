import Foundation

/// A file manager for nest
public struct NestDirectory: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
}

extension NestDirectory {
    public var bin: URL {
        rootDirectory.appending(component: "bin")
    }

    public var artifacts: URL {
        rootDirectory.appending(component: "artifacts")
    }

    public var infoJSON: URL {
        rootDirectory.appending(component: "info.json")
    }

    public func repository(gitURL: GitURL) -> URL {
        let scheme: String?
        let host: String?
        let pathComponents: [String]

        switch gitURL {
        case .url(let url):
            scheme = url.scheme
            host = url.host()
            pathComponents = Array(url.pathComponents.dropFirst())
        case .ssh(let sshURL):
            scheme = sshURL.user
            host = sshURL.host
            pathComponents = sshURL.path.split(separator: "/").compactMap { String($0) }
        }

        let components = pathComponents + [host, scheme].compactMap { $0 }
        return artifacts.appending(path: components.joined(separator: "_"))
    }

    public func version(gitURL: GitURL, version: String) -> URL {
        repository(gitURL: gitURL).appending(path: version)
    }

    public func binaryDirectory(gitURL: GitURL, version: String, manufacturer: ExecutableManufacturer) -> URL {
        let directoryName = switch manufacturer {
        case .artifactBundle(let fileName): fileName
        case .localBuild: "local_build"
        }
        return self.version(gitURL: gitURL, version: version).appending(path: directoryName)
    }

    public func binaryDirectory(of binary: ExecutableBinary) -> URL {
        binaryDirectory(
            gitURL: binary.gitURL,
            version: binary.version,
            manufacturer: binary.manufacturer
        )
    }

    public func binaryPath(of binary: ExecutableBinary) -> URL {
        binaryDirectory(of: binary).appending(path: binary.commandName)
    }

    public func symbolicPath(name: String) -> URL {
        bin.appending(path: name)
    }

    func relativePath(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: rootDirectory.absoluteString, with: "")
    }
}
