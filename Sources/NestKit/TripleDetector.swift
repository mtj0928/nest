import  Foundation

public struct TripleDetector {
    public init() {}

    public func detect() async throws -> String {
        let result = try await SwiftCommand().targetInfo()
        guard let data = result.data(using: .utf8) else {
            fatalError("Invalid result")
        }
        let info = try JSONDecoder().decode(SwiftTargetInfo.self, from: data)
        return info.target.unversionedTriple
    }
}

struct SwiftCommand {
    func targetInfo() async throws -> String {
        let swift = try await swiftPath()
        return try await ProcessExecutor().executeAndWait(command: swift, "-print-target-info")
    }

    private func swiftPath() async throws -> String {
        try await ProcessExecutor().executeAndWait(command: "/usr/bin/which", "swift")
    }
}

public struct SwiftTargetInfo: Codable {
    public let target: SwiftTarget

    public init(target: SwiftTarget) {
        self.target = target
    }
}

public struct SwiftTarget: Codable {
    public let unversionedTriple: String

    public init(unversionedTriple: String) {
        self.unversionedTriple = unversionedTriple
    }
}
