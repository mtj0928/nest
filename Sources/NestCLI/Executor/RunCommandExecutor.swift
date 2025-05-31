import NestKit
import Logging

public struct RunCommandExecutor {
    /// `owner/repo` format
    public let reference: String
    public let subcommands: [String]
    
    public enum ParseError: Error {
        case emptyArguments
        case invalidFormat
    }
    
    public init(arguments: [String]) throws(ParseError) {
        guard !arguments.isEmpty else {
            throw ParseError.emptyArguments
        }
        guard arguments[0].contains("/") else {
            throw ParseError.invalidFormat
        }
        
        self.reference = arguments[0]
        self.subcommands = if arguments.count >= 2 {
            Array(arguments[1...])
        } else {
            []
        }
    }
    
    /// Returns a relative path. If not, it will attempt to install.
    public func resolveBinaryRelativePath(
        noInstall: Bool,
        reference: String,
        version: String,
        target: Nestfile.Target,
        gitURL: GitURL,
        gitVersion: GitVersion,
        nestInfoController: NestInfoController,
        executableBinaryPreparer: ExecutableBinaryPreparer,
        artifactBundleManager: ArtifactBundleManager,
        logger: Logger
    ) async throws -> String? {
        if let binaryRelativePath = nestInfoController.command(matchingTo: reference, version: version)?.binaryPath {
            return binaryRelativePath
        }
        guard !noInstall else { return nil }

        let executableBinaries = try await executableBinaryPreparer.fetchOrBuildBinariesFromGitRepository(
            at: gitURL,
            version: gitVersion,
            artifactBundleZipFileName: target.assetName,
            checksum: ChecksumOption(expectedChecksum: target.checksum, logger: logger)
        )

        for binary in executableBinaries {
            try artifactBundleManager.install(binary)
            logger.info("🪺 Success to install \(binary.commandName) version \(binary.version).")
        }
        guard let binaryRelativePath = nestInfoController.command(matchingTo: reference, version: version)?.binaryPath else {
            return nil
        }
        return binaryRelativePath
    }
}
