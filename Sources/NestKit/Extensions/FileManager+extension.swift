import Foundation

extension FileManager {
    public func removeItemIfExists(at path: URL) throws {
        if fileExists(atPath: path.path()) {
            try removeItem(atPath: path.path())
        }
    }

    public func child(extension extensionName: String, at url: URL) throws -> [URL] {
        try contentsOfDirectory(atPath: url.path())
            .map { url.appending(component: $0) }
            .filter { $0.pathExtension == extensionName }
    }
}
