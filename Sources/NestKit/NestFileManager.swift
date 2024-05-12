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

    public func uninstall(command name: String) throws {
        let info = nestInfoRepository.getInfo()
        guard let commands = info.commands[name] else { return }

        for command in commands {
            let symbolicFilePath = directory.symbolicPath(name: name)
            if command.isLinked && fileManager.fileExists(atPath: symbolicFilePath.path()) {
                try? fileManager.removeItem(at: symbolicFilePath)
            }
            try? fileManager.removeItem(atPath: directory.rootDirectory.path() + command.binaryPath)
        }
        try nestInfoRepository.updateInfo { info in
            info.commands.removeValue(forKey: name)
        }
    }

    public func list() -> [String: [NestInfo.Command]] {
        nestInfoRepository.getInfo().commands
    }

    private func add(_ binary: ExecutableBinary) throws {
        let binaryPath = directory.binaryPath(of: binary)
        try fileManager.removeItemIfExists(at: binaryPath)
        try fileManager.moveItem(at: binary.binaryPath, to: binaryPath)

        try nestInfoRepository.updateInfo { info in
            var commands = info.commands[binary.commandName, default: []]
            commands = commands.filter { $0.binaryPath != directory.relativePath(binaryPath)  }
            commands.append(.init(binaryPath: directory.relativePath(binaryPath), isLinked: false, version: binary.version))
            info.commands[binary.commandName] = commands
        }
    }

    private func link(_ binary: ExecutableBinary) throws {
        try fileManager.createDirectory(at: directory.bin, withIntermediateDirectories: true)

        let symbolicURL = directory.symbolicPath(name: binary.commandName)
        try fileManager.removeItemIfExists(at: symbolicURL)

        let binaryPath = directory.binaryPath(of: binary)
        try fileManager.createSymbolicLink(at: symbolicURL, withDestinationURL: binaryPath)

        try nestInfoRepository.updateInfo { info in
            info.commands[binary.commandName] = info.commands[binary.commandName]?.map { command in
                var command = command
                command.isLinked = command.binaryPath == directory.relativePath(binaryPath)
                return command
            }
        }
    }
}

extension NestFileManager {
    var nestInfoRepository: NestInfoRepository {
        NestInfoRepository(directory: directory, fileManager: fileManager)
    }
}

struct NestInfoRepository {
    private let directory: NestDirectory
    private let fileManager: FileManager

    init(directory: NestDirectory, fileManager: FileManager) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func updateInfo(_ updater: (inout NestInfo) -> Void) throws {
        var infoJSON: NestInfo
        if fileManager.fileExists(atPath: directory.infoJSON.path()) {
            let data = try Data(contentsOf: directory.infoJSON)
            infoJSON = try JSONDecoder().decode(NestInfo.self, from: data)
        } else {
            infoJSON = NestInfo(version: NestInfo.currentVersion, commands: [:])
        }
        updater(&infoJSON)

        // Format
        for (name, commands) in infoJSON.commands {
            infoJSON.commands[name] = commands.sorted(by: { $0.version >= $1.version })
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted, .sortedKeys]
        let updateData = try encoder.encode(infoJSON)
        try updateData.write(to: directory.infoJSON)
    }

    func getInfo() -> NestInfo {
        do {
            if fileManager.fileExists(atPath: directory.infoJSON.path()) {
                let data = try Data(contentsOf: directory.infoJSON)
                return try JSONDecoder().decode(NestInfo.self, from: data)
            }
        }
        catch {}
        return NestInfo(version: NestInfo.currentVersion, commands: [:])
    }
}
