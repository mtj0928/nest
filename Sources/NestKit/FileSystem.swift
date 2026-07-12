import Darwin
import Foundation
import ZIPFoundation

public protocol FileSystem: Sendable {
    var homeDirectoryForCurrentUser: URL { get }
    var temporaryDirectory: URL { get }

    func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func removeItem(at URL: URL) throws
    func child(at url: URL) throws -> [URL]
    func copyItem(at srcURL: URL, to dstURL: URL) throws
    func replaceItemAtomically(at sourceURL: URL, to destinationURL: URL) throws
    func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) throws
    func destinationOfSymbolicLink(atPath path: String) throws -> String
    func unzip(
        at sourceURL: URL,
        to destinationURL: URL,
        skipCRC32: Bool,
        allowUncontainedSymlinks: Bool,
        progress: Progress?,
        pathEncoding: String.Encoding?
    ) throws
    func fileExists(atPath path: String) -> Bool
    func data(at url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
}

extension FileSystem {
    public func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool
    ) throws {
        try createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: nil)
    }

    public func unzip(at sourceURL: URL, to destinationURL: URL) throws {
        do {
            try unzip(
                at: sourceURL,
                to: destinationURL,
                skipCRC32: false,
                allowUncontainedSymlinks: false,
                progress: nil,
                pathEncoding: nil
            )
        } catch let error as Archive.ArchiveError {
            throw InvalidZIPArchiveError(underlyingError: error)
        }
    }

    public func child(extension extensionName: String, at url: URL) throws -> [URL] {
        try child(at: url)
            .filter { $0.pathExtension == extensionName }
    }

    public func removeItemIfExists(at path: URL) throws {
        if fileExists(atPath: path.path()) {
            try removeItem(at: path)
        }
    }

    /// Copies a file to a sibling temporary path and atomically publishes the completed copy.
    public func copyItemAtomicallyReplacingDestination(at sourceURL: URL, to destinationURL: URL) throws {
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let temporaryURL = destinationDirectory.appending(
            component: ".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        defer { try? removeItemIfExists(at: temporaryURL) }

        try copyItem(at: sourceURL, to: temporaryURL)
        try replaceItemAtomically(at: temporaryURL, to: destinationURL)
    }

    public func child(at url: URL) throws -> [URL] {
        try contentsOfDirectory(atPath: url.path())
            .map { url.appending(component: $0) }
    }

    public func removeEmptyDirectory(from path: URL, until rootPath: URL) throws {
        var targetPath = path
        while (try? contentsOfDirectory(atPath: targetPath.path()).isEmpty) ?? false,
              targetPath != rootPath {
            try removeItemIfExists(at: targetPath)
            targetPath = targetPath.deletingLastPathComponent()
        }
    }
}

extension FileManager: FileSystem {
    public func replaceItemAtomically(at sourceURL: URL, to destinationURL: URL) throws {
        if Darwin.rename(sourceURL.path(), destinationURL.path()) != 0 {
            let errorCode = errno
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errorCode))
        }
    }

    public func data(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    public func unzip(
        at sourceURL: URL,
        to destinationURL: URL,
        skipCRC32: Bool,
        allowUncontainedSymlinks: Bool,
        progress: Progress?,
        pathEncoding: String.Encoding?
    ) throws {
        try self.unzipItem(
            at: sourceURL,
            to: destinationURL,
            skipCRC32: skipCRC32,
            allowUncontainedSymlinks: allowUncontainedSymlinks,
            progress: progress,
            pathEncoding: pathEncoding
        )
    }
}
