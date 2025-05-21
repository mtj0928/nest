import Foundation

public struct NestInfoController {
    private let directory: NestDirectory
    private let fileSystem: any FileSystem

    public init(directory: NestDirectory, fileSystem: some FileSystem) {
        self.directory = directory
        self.fileSystem = fileSystem
    }

    public func getInfo() -> NestInfo {
        guard fileSystem.fileExists(atPath: directory.infoJSON.path()),
              let data = try? fileSystem.data(at: directory.infoJSON),
              let nestInfo = try? JSONDecoder().decode(NestInfo.self, from: data)
        else {
            return NestInfo(version: NestInfo.currentVersion, commands: [:])
        }
        return nestInfo
    }

    /// Get NestInfo.Command from `owner/repository`
    public func command(matchingTo reference: String, version: String) -> NestInfo.Command? {
         return getInfo().commands
            .first {
                $0.value
                    .contains {
                        switch $0.manufacturer {
                        case let .artifactBundle(sourceInfo):
                            return sourceInfo.repository?.reference.reference == reference
                        case let .localBuild(repository):
                            return repository.reference.reference == reference
                        }
                    }
            }?.value
            .first { $0.version == version }
    }

    func remove(command: String, version: String) throws {
        try updateInfo { info in
            info.commands[command] = info.commands[command]?.filter { $0.version != version }
            if info.commands[command]?.isEmpty ?? false {
                info.commands.removeValue(forKey: command)
            }
        }
    }

    func add(name: String, command: NestInfo.Command) throws {
        try updateInfo { info in
            var commands = info.commands[name, default: []]
            commands = commands.filter { $0.binaryPath != command.binaryPath  }
            commands.append(command)
            info.commands[name] = commands
        }
    }
}

extension NestInfoController {
    private func updateInfo(_ updater: (inout NestInfo) -> Void) throws {
        var infoJSON: NestInfo
        if fileSystem.fileExists(atPath: directory.infoJSON.path()) {
            let data = try fileSystem.data(at: directory.infoJSON)
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
#if DEBUG
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys, .prettyPrinted]
#else
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
#endif
        let updateData = try encoder.encode(infoJSON)
        try fileSystem.write(updateData, to: directory.infoJSON)
    }
}
