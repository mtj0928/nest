import Foundation

public struct NestFileManager: Sendable {
    private let fileManager: FileManager
    private let directory: NestDirectory

    public init(fileManager: FileManager, directory: NestDirectory) {
        self.fileManager = fileManager
        self.directory = directory
    }

    public func install(_ binary: ExecutableBinary) throws {
        let binaryDirectory = directory.binaryDirectory(of: binary)
        try fileManager.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)

        let binaryPath = binaryDirectory.appending(path: binary.commandName)
        try fileManager.removeItemIfExists(at: binaryPath)
        try fileManager.moveItem(at: binary.binaryPath, to: binaryPath)

        try fileManager.createDirectory(at: directory.bin, withIntermediateDirectories: true)
        let symbolicURL = directory.bin.appending(path: binary.commandName)
        try fileManager.removeItemIfExists(at: symbolicURL)
        try fileManager.createSymbolicLink(at: symbolicURL, withDestinationURL: binaryPath)
    }
}
