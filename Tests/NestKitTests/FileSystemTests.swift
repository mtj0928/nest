import Foundation
import NestKit
import Testing

struct FileSystemTests {
    @Test
    func copyItemAtomicallyReplacesDestination() throws {
        let fileSystem = FileManager.default
        let directory = fileSystem.temporaryDirectory.appending(
            component: "nest-file-system-tests-\(UUID().uuidString)"
        )
        let cacheDirectory = directory.appending(component: "cache")
        let sourceURL = directory.appending(component: "source.zip")
        let destinationURL = cacheDirectory.appending(component: "destination.zip")
        try fileSystem.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        defer { try? fileSystem.removeItem(at: directory) }
        try fileSystem.write(Data("new".utf8), to: sourceURL)
        try fileSystem.write(Data("old".utf8), to: destinationURL)

        try fileSystem.copyItemAtomicallyReplacingDestination(at: sourceURL, to: destinationURL)

        #expect(try fileSystem.data(at: sourceURL) == Data("new".utf8))
        #expect(try fileSystem.data(at: destinationURL) == Data("new".utf8))
        #expect(try fileSystem.contentsOfDirectory(atPath: cacheDirectory.path()) == ["destination.zip"])
    }
}
