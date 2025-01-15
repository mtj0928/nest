import Foundation
import ZIPFoundation
import os
import NestKit

public final class MockFileSystem: FileSystem, Sendable {
    public var item: FileSystemItem {
        get { lockedItem.withLock { $0 } }
        set { lockedItem.withLock { $0 = newValue } }
    }
    public var symbolicLink: [URL: URL] {
        get { lockedSymbolicLink.withLock { $0 } }
        set { lockedSymbolicLink.withLock { $0 = newValue } }
    }

    public let homeDirectoryForCurrentUser: URL
    public let temporaryDirectory: URL

    private let lockedItem = OSAllocatedUnfairLock(initialState: FileSystemItem.directory(children: [:]))
    private let lockedSymbolicLink = OSAllocatedUnfairLock(initialState: [URL: URL]())

    public init(homeDirectoryForCurrentUser: URL, temporaryDirectory: URL) {
        self.homeDirectoryForCurrentUser = homeDirectoryForCurrentUser
        self.temporaryDirectory = temporaryDirectory
    }

    public func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        lockedItem.withLock { item in
            if createIntermediates {
                let components = url.pathComponents
                var currentComponents: [String] = []
                for component in components {
                    currentComponents.append(component)
                    if item.item(components: currentComponents) != nil {
                        continue
                    }
                    item.update(item: .directory(children: [:]), at: currentComponents)
                }
            } else {
                item.update(item: .directory(children: [:]), at: url.pathComponents)
            }
        }
    }

    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        try lockedItem.withLock { item in
            let originalURL = URL(fileURLWithPath: path)
            let url = symbolicLink[originalURL] ?? originalURL

            guard case .directory(let children) = item.item(components: url.pathComponents) else {
                throw MockFileSystemError.fileNotFound
            }
            return children.keys.map { $0 }
        }
    }

    public func removeItem(at originalURL: URL) throws {
        lockedItem.withLock { item in
            let url = symbolicLink[originalURL] ?? originalURL
            item.remove(at: url.pathComponents)
            symbolicLink.removeValue(forKey: originalURL)
        }
    }

    public func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try lockedItem.withLock { item in
            let srcURL = self.symbolicLink[srcURL] ?? srcURL
            let dstURL = self.symbolicLink[dstURL] ?? dstURL
            guard let sourceItem = item.item(components: srcURL.pathComponents) else {
                throw MockFileSystemError.fileNotFound
            }
            item.update(item: sourceItem, at: dstURL.pathComponents)
        }
    }

    public func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) throws {
        symbolicLink[url] = destURL
    }

    public func destinationOfSymbolicLink(atPath path: String) throws -> String {
        guard let result = symbolicLink[URL(fileURLWithPath: path)] else {
            throw MockFileSystemError.fileNotFound
        }
        return result.path()
    }

    public func fileExists(atPath path: String) -> Bool {
        lockedItem.withLock { item in
            let originalURL = URL(filePath: path)
            let url = symbolicLink[originalURL] ?? originalURL
            let components = url.pathComponents
            return item.item(components: components) != nil
        }
    }

    public func unzip(
        at sourceURL: URL,
        to destinationURL: URL,
        skipCRC32: Bool,
        allowUncontainedSymlinks: Bool,
        progress: Progress?,
        pathEncoding: String.Encoding?
    ) throws {
        let sourceURL = symbolicLink[sourceURL] ?? sourceURL
        let destinationURL = symbolicLink[destinationURL] ?? destinationURL
        try createDirectory(at: destinationURL, withIntermediateDirectories: true)

        guard let data = try? self.data(at: sourceURL) else {
            return
        }
        let archive = try Archive(data: data, accessMode: .update)

        try archive
            .filter { $0.type == .directory }
            .map(\.path)
            .forEach { directory in
                try createDirectory(at: destinationURL.appending(path: directory), withIntermediateDirectories: true)
            }

        try archive.filter { $0.type == .file }
            .forEach { entry in
                var data = Data()
                _ = try archive.extract(entry) { chunk in
                    data += chunk
                }
                try write(data, to: destinationURL.appending(path: entry.path))
            }
    }

    public func data(at url: URL) throws -> Data {
        try lockedItem.withLock { item in
            let url = symbolicLink[url] ?? url
            let components = url.pathComponents
            switch item.item(components: components) {
            case .file(let data): return data
            default: throw MockFileSystemError.fileNotFound
            }
        }
    }

    public func write(_ data: Data, to url: URL) throws {
        lockedItem.withLock { item in
            let components = url.pathComponents
            item.update(item: .file(data: data), at: components)
        }
    }
}

extension MockFileSystem {
    public func printStructure() {
        item.printStructure()
        for (sourceURL, destinationURL) in symbolicLink {
            print("\(sourceURL.path()) -> \(destinationURL.path())")
        }
    }

    public enum MockFileSystemError: Error {
        case fileNotFound
    }
}
