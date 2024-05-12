import Foundation

public struct ArtifactBundleRootDirectory {
    public let info: ArtifactBundleInfo
    public let rootDirectory: URL
    public let gitURL: GitURL

    public init(at path: URL, gitURL: GitURL) throws {
        let infoPath = path.appending(path: "info.json")
        let data = try Data(contentsOf: infoPath)
        let info = try JSONDecoder().decode(ArtifactBundleInfo.self, from: data)

        self.info = info
        self.rootDirectory = path
        self.gitURL = gitURL
    }
}

extension ArtifactBundleRootDirectory {

    public func binaries(of triple: String) -> [ExecutableBinary] {
        info.artifacts.flatMap { name, artifact in
            artifact.variants
                .filter { variant in variant.supportedTriples.contains(triple) }
                .map { variant in variant.path }
                .map { variantPath in rootDirectory.appending(path: variantPath) }
                .map { binaryPath in
                    let fileName = rootDirectory.fileNameWithoutPathExtension
                    return ExecutableBinary(
                        commandName: name,
                        binaryPath: binaryPath,
                        gitURL: gitURL,
                        version: artifact.version,
                        manufacturer: .artifactBundle(fileName: fileName)
                    )
                }
        }
    }
}
