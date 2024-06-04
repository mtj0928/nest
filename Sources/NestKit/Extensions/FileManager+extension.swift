import Foundation

extension FileManager {
    public func removeItemIfExists(at path: URL) throws {
        if fileExists(atPath: path.path()) {
            try removeItem(atPath: path.path())
        }
    }

    public func child(extension extensionName: String, at url: URL) throws -> [URL] {
        try child(at: url)
            .filter { $0.pathExtension == extensionName }
    }

    public func child(at url: URL) throws -> [URL] {
        try contentsOfDirectory(atPath: url.path())
            .map { url.appending(component: $0) }
    }

    public func removeItemAndParentDirectoryIfEmpty(at path: URL) throws {
        try removeItemIfExists(at: path)

        let directory = path.deletingLastPathComponent()

        if let contents = try? contentsOfDirectory(atPath: directory.path), contents.isEmpty {
            try removeItemIfExists(at: directory)
        }
    }
}
