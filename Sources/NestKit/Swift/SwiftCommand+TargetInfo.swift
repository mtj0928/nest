import Foundation

extension SwiftCommand {
    public func targetInfo() async throws -> SwiftTargetInfo {
        let json = try await run("-print-target-info")
        return try JSONDecoder().decode(SwiftTargetInfo.self, from: json.data(using: .utf8)!)
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
