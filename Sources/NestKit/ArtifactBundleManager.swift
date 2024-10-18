import Foundation

public struct ArtifactBundleManager: Sendable {
    private let fileSystem: any FileSystem
    private let directory: NestDirectory

    public init(fileSystem: some FileSystem, directory: NestDirectory) {
        self.fileSystem = fileSystem
        self.directory = directory
    }
    
    /// Puts the binary to artifact bundle directory and make a symbolic link from the put binary to bin directory.
    public func install(_ binary: ExecutableBinary) throws {
        let binaryDirectory = directory.binaryDirectory(of: binary)
        try fileSystem.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)

        try add(binary)
        try link(binary)
    }

    public func uninstall(command name: String, version: String) throws {
        let info = nestInfoController.getInfo()
        guard var commands = info.commands[name] else { return }

        commands = commands.filter { $0.version == version }

        for command in commands {
            // Remove symboliklink
            if let linkedFilePath = try? self.linkedFilePath(commandName: name),
               linkedFilePath == command.binaryPath {
                let resourceNames = command.resourcePaths.map { directory.url($0).lastPathComponent }
                for target in resourceNames + [name] {
                    let symbolicFilePath = directory.symbolicPath(name: target)
                    try? fileSystem.removeItem(at: symbolicFilePath)
                }
            }

            // Remove files
            let binaryPath = URL(filePath: directory.rootDirectory.path() + command.binaryPath)
            try? fileSystem.removeItemIfExists(at: binaryPath)

            // Remove empty directories
            try fileSystem.removeEmptyDirectory(
                from: binaryPath.deletingLastPathComponent(),
                until: directory.rootDirectory
            )
        }
        try nestInfoController.remove(command: name, version: version)
    }

    public func list() -> [String: [NestInfo.Command]] {
        nestInfoController.getInfo().commands
    }

    private func add(_ binary: ExecutableBinary) throws {
        // Copy binary
        let binaryPath = directory.binaryPath(of: binary)
        try fileSystem.removeItemIfExists(at: binaryPath)
        try fileSystem.copyItem(at: binary.binaryPath, to: binaryPath)

        // Copy resources
        let resources = try resources(of: binary)
        var copiedResources: [URL] = []
        for resource in resources {
            let destination = directory.binaryDirectory(of: binary).appending(path: resource.lastPathComponent)
            try fileSystem.removeItemIfExists(at: destination)
            try fileSystem.copyItem(at: resource, to: destination)
            copiedResources.append(destination)
        }

        let command = NestInfo.Command(
            version: binary.version,
            binaryPath: directory.relativePath(binaryPath),
            resourcePaths: copiedResources.map { directory.relativePath($0) },
            manufacturer: binary.manufacturer
        )
        try nestInfoController.add(name: binary.commandName, command: command)
    }

    /// Makes a symbolic link for the given binary to bin directory.
    public func link(_ binary: ExecutableBinary) throws {
        try fileSystem.createDirectory(at: directory.bin, withIntermediateDirectories: true)

        // Check existing resources are not conflicted.
        let conflictingInfo = try extractConflictInfos(binary: binary)
        if !conflictingInfo.isEmpty {
            throw ArtifactBundleManagerError.resourceConflicting(
                commandName: binary.commandName,
                conflictingNames: conflictingInfo.map(\.commandName),
                resourceNames: conflictingInfo.flatMap(\.resourceNames)
            )
        }

        let resources = try resources(of: binary)
        for target in resources + [directory.binaryPath(of: binary)] {
            let symbolicURL = directory.symbolicPath(name: target.lastPathComponent)
            try fileSystem.removeItemIfExists(at: symbolicURL)

            let binaryPath = directory.binaryDirectory(of: binary).appending(path: target.lastPathComponent)
            try fileSystem.createSymbolicLink(at: symbolicURL, withDestinationURL: binaryPath)
        }
    }

    private func resources(of binary: ExecutableBinary) throws -> [URL] {
        try fileSystem.child(extension: "bundle", at: binary.parentDirectory)
            .filter { $0 != binary.binaryPath }
    }

    private func extractConflictInfos(binary: ExecutableBinary) throws -> [ConflictInfo] {
        let resourceNames = try resources(of: binary).map(\.lastPathComponent)
        
        let conflictingResourcesInBin = try fileSystem.child(at: directory.bin)
            .filter { resourceNames.contains($0.lastPathComponent) }
            .map(\.lastPathComponent)

        let info = nestInfoController.getInfo()

        let installedCommands = info.commands.compactMap { commandName, commands -> (String, NestInfo.Command)? in
            guard let command = commands.first(where: { isLinked(name: commandName, commend: $0) }) else { return nil }
            return (commandName, command)
        }

        let conflictingInfos = installedCommands.compactMap { name, command -> ConflictInfo? in
            if name == binary.commandName {
                return nil
            }
            let resourceNames = command.resourcePaths
                .map { directory.url($0) }
                .map(\.lastPathComponent)
            let conflictingResourceNames = conflictingResourcesInBin.filter { resourceName in
                resourceNames.contains(resourceName)
            }
            if conflictingResourceNames.isEmpty {
                return nil
            }
            return ConflictInfo(commandName: name, resourceNames: conflictingResourceNames)
        }
        return conflictingInfos
    }

    struct ConflictInfo {
        let commandName: String
        let resourceNames: [String]
    }
}

extension ArtifactBundleManager {
    var nestInfoController: NestInfoController {
        NestInfoController(directory: directory, fileSystem: fileSystem)
    }

    public func isLinked(name: String, commend: NestInfo.Command) -> Bool {
        (try? self.linkedFilePath(commandName: name)) == commend.binaryPath
    }

    private func linkedFilePath(commandName: String) throws -> String {
        let urlString = try fileSystem.destinationOfSymbolicLink(atPath: directory.symbolicPath(name: commandName).path())
        let url = URL(filePath: urlString)
        return directory.relativePath(url)
    }
}

enum ArtifactBundleManagerError: LocalizedError {
    case resourceConflicting(commandName: String, conflictingNames: [String], resourceNames: [String])

    var errorDescription: String? {
        switch self {
        case .resourceConflicting(let name, let conflictingNames, let resourceNames):
            return """
                \(conflictingNames.joined(separator: ", ")) and \(name) are not installed at the same, because resource names (\(resourceNames.joined(separator: ","))) are conflicting.
                """
        }
    }
}
