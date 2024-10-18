import Foundation
import os
import NestKit

final class MockFileStorage: FileStorage, @unchecked Sendable {
    var item: FileStorageItem {
        get { lockedItem.withLock { $0 } }
        set { lockedItem.withLock { $0 = newValue } }
    }
    var symbolicLink: [URL: URL] {
        get { lockedSymbolicLink.withLock { $0 } }
        set { lockedSymbolicLink.withLock { $0 = newValue } }
    }

    let homeDirectoryForCurrentUser: URL
    let temporaryDirectory: URL

    private let lockedItem = OSAllocatedUnfairLock(initialState: FileStorageItem.directory(children: [:]))
    private let lockedSymbolicLink = OSAllocatedUnfairLock(initialState: [URL: URL]())

    init(homeDirectoryForCurrentUser: URL, temporaryDirectory: URL) {
        self.homeDirectoryForCurrentUser = homeDirectoryForCurrentUser
        self.temporaryDirectory = temporaryDirectory
    }

    func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
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

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        let originalURL = URL(fileURLWithPath: path)
        let url = symbolicLink[originalURL] ?? originalURL

        guard case .directory(let children) = item.item(components: url.pathComponents) else {
            throw MockFileStorageError.fileNotFound
        }
        return children.keys.map { $0 }
    }

    func removeItem(at originalURL: URL) throws {
        let url = symbolicLink[originalURL] ?? originalURL
        item.remove(at: url.pathComponents)
        symbolicLink.removeValue(forKey: originalURL)
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        let srcURL = symbolicLink[srcURL] ?? srcURL
        let dstURL = symbolicLink[dstURL] ?? dstURL
        guard let item = item.item(components: srcURL.pathComponents) else {
            throw MockFileStorageError.fileNotFound
        }
        self.item.update(item: item, at: dstURL.pathComponents)
    }

    func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) throws {
        symbolicLink[url] = destURL
    }

    func destinationOfSymbolicLink(atPath path: String) throws -> String {
        guard let result = symbolicLink[URL(fileURLWithPath: path)] else {
            throw MockFileStorageError.fileNotFound
        }
        return result.path()
    }

    func fileExists(atPath path: String) -> Bool {
        let originalURL = URL(filePath: path)
        let url = symbolicLink[originalURL] ?? originalURL
        let components = url.pathComponents
        return item.item(components: components) != nil
    }

    func data(at url: URL) throws -> Data {
        let url = symbolicLink[url] ?? url
        let components = url.pathComponents
        switch item.item(components: components) {
        case .file(let data): return data
        default: throw MockFileStorageError.fileNotFound
        }
    }

    func write(_ data: Data, to url: URL) throws {
        let components = url.pathComponents
        item.update(item: .file(data: data), at: components)
    }
}

extension MockFileStorage {
    func printStructure() {
        item.printStructure()
        for (sourceURL, destinationURL) in symbolicLink {
            print("\(sourceURL.path()) -> \(destinationURL.path())")
        }
    }

    enum MockFileStorageError: Error {
        case fileNotFound
    }
}
