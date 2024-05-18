import Foundation

/// A directory structure for nest.
public struct NestDirectory: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
}

extension NestDirectory {

    /// `root/info.json`
    public var infoJSON: URL {
        rootDirectory.appending(component: "info.json")
    }

    /// `root/bin`
    public var bin: URL {
        rootDirectory.appending(component: "bin")
    }

    /// `root/artifacts`
    public var artifacts: URL {
        rootDirectory.appending(component: "artifacts")
    }

    /// `root/artifacts/{source}`
    public func source(_ manufacturer: ExecutableManufacturer) -> URL {
        func sourceIdentifier(_ url: URL) -> String {
            let scheme = url.scheme
            let host = url.host()
            let pathComponents = Array(url.pathComponents.dropFirst())
            let components = pathComponents + [host, scheme].compactMap { $0 }
            return components.joined(separator: "_")
        }

        func sourceIdentifier(_ gitURL: GitURL) -> String {
            switch gitURL {
            case .url(let url): return sourceIdentifier(url)
            case .ssh(let sshURL):
                let pathComponents = sshURL.path.split(separator: "/").compactMap { String($0) }
                return (pathComponents + [sshURL.host, sshURL.user]).joined(separator: "_")
            }
        }

        let component = switch manufacturer {
        case .artifactBundle(let sourceInfo):
            sourceInfo.repository.map { sourceIdentifier($0.reference) } ?? sourceIdentifier(sourceInfo.zipURL)
        case .localBuild(let repository): sourceIdentifier(repository.reference)
        }
        return artifacts.appending(component: component)
    }


    /// `root/artifacts/{source}/{version}`
    public func version(manufacturer: ExecutableManufacturer, version: String) -> URL {
        source(manufacturer).appending(path: version)
    }

    /// `root/artifacts/{source}/{version}/{build kind}`
    public func binaryDirectory( manufacturer: ExecutableManufacturer, version: String) -> URL {
        let directoryName = switch manufacturer {
        case .artifactBundle(let sourceInfo): 
            sourceInfo.zipURL.lastPathComponent
                .replacingOccurrences(of: ".zip", with: "")
                .replacingOccurrences(of: ".artifactbundle", with: "")
        case .localBuild: "local_build"
        }
        return self.version(manufacturer: manufacturer, version: version).appending(path: directoryName)
    }

    /// `root/artifacts/{source}/{version}/{build kind}`
    public func binaryDirectory(of binary: ExecutableBinary) -> URL {
        let version = switch binary.manufacturer {
        case .artifactBundle(let sourceInfo): sourceInfo.repository?.version ?? "unknown"
        case .localBuild(let repository): repository.version
        }
        return binaryDirectory(manufacturer: binary.manufacturer, version: version)
    }

    /// `root/artifacts/{source}/{version}/{build kind}/{binary}`
    public func binaryPath(of binary: ExecutableBinary) -> URL {
        binaryDirectory(of: binary).appending(path: binary.commandName)
    }

    /// `root/bin/{binary}`
    public func symbolicPath(name: String) -> URL {
        bin.appending(path: name)
    }

    public func relativePath(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: rootDirectory.absoluteString, with: "")
    }

    public func url(_ path: String) -> URL {
        rootDirectory.appending(path: path)
    }
}
