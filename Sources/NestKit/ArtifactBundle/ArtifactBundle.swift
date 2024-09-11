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
