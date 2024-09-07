import Foundation

/// A data model representing artifact bundle.
public struct ArtifactBundle: Sendable {
    /// A data of info.json in artifact bundle.
    public let info: ArtifactBundleInfo

    /// A directory where the artifact bundle is located
    public let rootDirectory: URL

    /// A information where the artifact bundle is from.
    public let sourceInfo: ArtifactBundleSourceInfo

    public init(at path: URL, sourceInfo: ArtifactBundleSourceInfo) throws {
        let infoPath = path.appending(path: "info.json")
        let data = try Data(contentsOf: infoPath)
        let info = try JSONDecoder().decode(ArtifactBundleInfo.self, from: data)

        self.info = info
        self.rootDirectory = path
        self.sourceInfo = sourceInfo
    }
}

extension ArtifactBundle {

    public func binaries(of triple: String) -> [ExecutableBinary] {
        info.artifacts.flatMap { name, artifact in
            artifact.variants
                .filter { variant in variant.supportedTriples.contains(triple) }
                .map { variant in variant.path }
                .map { variantPath in rootDirectory.appending(path: variantPath) }
                .map { binaryPath in
                    ExecutableBinary(
                        commandName: name,
                        binaryPath: binaryPath,
                        version: artifact.version,
                        manufacturer: .artifactBundle(sourceInfo: sourceInfo)
                    )
                }
        }
    }
}
