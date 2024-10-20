public protocol ChecksumCalculator: Sendable {
    func calculate(_ path: String) async throws -> String
}

public struct SwiftChecksumCalculator: ChecksumCalculator {
    let swift: SwiftCommand

    public init(swift: SwiftCommand) {
        self.swift = swift
    }

    public init(processExecutor: ProcessExecutor) {
        self.swift = SwiftCommand(executor: processExecutor)
    }

    public func calculate(_ path: String) async throws -> String {
        try await swift.computeCheckSum(path: path)
    }
}
