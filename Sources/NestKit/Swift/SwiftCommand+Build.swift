extension SwiftCommand {
    public func buildForRelease() async throws {
        _ = try await run("build", "-c", "release")
    }
}
