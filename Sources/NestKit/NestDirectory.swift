import Foundation

/// A file manager for nest
public struct NestDirectory: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
}

public struct ExecutableBinary {
    public var commandName: String
    public var binaryPath: URL
    public var gitURL: GitURL
    public var version: String
    public var artifactBundleFileName: String

    public init(commandName: String, binaryPath: URL, gitURL: GitURL, version: String, artifactBundleFileName: String) {
        self.commandName = commandName
        self.binaryPath = binaryPath
        self.gitURL = gitURL
        self.version = version
        self.artifactBundleFileName = artifactBundleFileName
    }
}

extension NestDirectory {
    public var bin: URL {
        rootDirectory.appending(component: "bin")
    }

    public var artifacts: URL {
        rootDirectory.appending(component: "artifacts")
    }

    public func repository(gitURL: GitURL) -> URL {
        let path = switch gitURL {
        case .url(let url): 
            url.pathComponents.dropFirst().joined(separator: "_")
        case .ssh(let sshURL): 
            [sshURL.user, sshURL.host, sshURL.path.replacingOccurrences(of: "/", with: "_")]
                .joined(separator: "_")
        }

        return artifacts.appending(path: path)
    }

    public func version(gitURL: GitURL, version: String) -> URL {
        repository(gitURL: gitURL).appending(path: version)
    }

    public func binaryDirectory(gitURL: GitURL, version: String, artifactBundleName: String) -> URL {
        self.version(gitURL: gitURL, version: version).appending(path: artifactBundleName)
    }

    public func binaryDirectory(of binary: ExecutableBinary) -> URL {
        self.binaryDirectory(
            gitURL: binary.gitURL,
            version: binary.version,
            artifactBundleName: binary.artifactBundleFileName
        )
    }
}
