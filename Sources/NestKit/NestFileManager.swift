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

        try add(binary)
        try link(binary)
    }

    public func uninstall(command name: String, version: String) throws {
        let info = nestInfoRepository.getInfo()
        guard var commands = info.commands[name] else { return }

        commands = commands.filter { $0.version == version }

        for command in commands {
            let symbolicFilePath = directory.symbolicPath(name: name)
            if command.isLinked && fileManager.fileExists(atPath: symbolicFilePath.path()) {
                try? fileManager.removeItem(at: symbolicFilePath)
            }

            let binaryPath = URL(filePath: directory.rootDirectory.path() + command.binaryPath)
            try? fileManager.removeItemIfExists(at: binaryPath)

            // Remove empty directories
            var targetPath = binaryPath.deletingLastPathComponent()
            while (try? fileManager.contentsOfDirectory(atPath: targetPath.path()).isEmpty) ?? false,
                  targetPath != directory.rootDirectory {
                try fileManager.removeItemIfExists(at: targetPath)
                targetPath = targetPath.deletingLastPathComponent()
            }
        }
        try nestInfoRepository.remove(command: name, version: version)
    }

    public func list() -> [String: [NestInfo.Command]] {
        nestInfoRepository.getInfo().commands
    }

    private func add(_ binary: ExecutableBinary) throws {
        let binaryPath = directory.binaryPath(of: binary)
        try fileManager.removeItemIfExists(at: binaryPath)
        try fileManager.moveItem(at: binary.binaryPath, to: binaryPath)

        let command = NestInfo.Command(
            source: binary.source,
            binaryPath: directory.relativePath(binaryPath),
            isLinked: false,
            version: binary.version
        )
        try nestInfoRepository.add(name: binary.commandName, command: command)
    }

    private func link(_ binary: ExecutableBinary) throws {
        try fileManager.createDirectory(at: directory.bin, withIntermediateDirectories: true)

        let symbolicURL = directory.symbolicPath(name: binary.commandName)
        try fileManager.removeItemIfExists(at: symbolicURL)

        let binaryPath = directory.binaryPath(of: binary)
        try fileManager.createSymbolicLink(at: symbolicURL, withDestinationURL: binaryPath)

        try nestInfoRepository.link(name: binary.commandName, binaryPath: directory.relativePath(binaryPath))
    }
}

extension NestFileManager {
    var nestInfoRepository: NestInfoRepository {
        NestInfoRepository(directory: directory, fileManager: fileManager)
    }
}
