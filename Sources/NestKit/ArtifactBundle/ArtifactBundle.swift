import Foundation

/// A data model representing artifact bundle.
public struct ArtifactBundle: Sendable {
    /// A data of info.json in artifact bundle.
    public let info: ArtifactBundleInfo

    /// A directory where the artifact bundle is located
    public let rootDirectory: URL

    /// A information where the artifact bundle is from.
    public let sourceInfo: ArtifactBundleSourceInfo

    public init(info: ArtifactBundleInfo, rootDirectory: URL, sourceInfo: ArtifactBundleSourceInfo) {
        self.info = info
        self.rootDirectory = rootDirectory
        self.sourceInfo = sourceInfo
    }
}

extension ArtifactBundle {
    public static func load(
        at path: URL,
        sourceInfo: ArtifactBundleSourceInfo,
        fileSystem: some FileSystem
    ) throws -> ArtifactBundle {
        let infoPath = path.appending(path: "info.json")
        let data = try fileSystem.data(at: infoPath)
        let info = try JSONDecoder().decode(ArtifactBundleInfo.self, from: data)

        return ArtifactBundle(info: info, rootDirectory: path, sourceInfo: sourceInfo)
    }
}
