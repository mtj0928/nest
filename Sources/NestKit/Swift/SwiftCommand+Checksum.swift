extension SwiftCommand {
    public func computeCheckSum(path: String) async throws -> String {
        try await run("package", "compute-checksum", path)
    }
}
