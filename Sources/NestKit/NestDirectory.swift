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

    public func source(source: ExecutorBinarySource) -> URL {
        artifacts.appending(component: source.identifier)
    }

    public func version(source: ExecutorBinarySource, version: String) -> URL {
        self.source(source: source).appending(path: version)
    }

    public func binaryDirectory(source: ExecutorBinarySource, version: String, manufacturer: ExecutableManufacturer) -> URL {
        let directoryName = switch manufacturer {
        case .artifactBundle(let fileName): fileName
        case .localBuild: "local_build"
        }
        return self.version(source: source, version: version).appending(path: directoryName)
    }

    public func binaryDirectory(of binary: ExecutableBinary) -> URL {
        binaryDirectory(
            source: binary.source,
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
