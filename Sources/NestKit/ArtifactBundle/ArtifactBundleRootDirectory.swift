import Foundation

public struct ArtifactBundleRootDirectory {
    public let info: ArtifactBundleInfo
    public let rootDirectory: URL
    public let source: ExecutorBinarySource

    public init(at path: URL, source: ExecutorBinarySource) throws {
        let infoPath = path.appending(path: "info.json")
        let data = try Data(contentsOf: infoPath)
        let info = try JSONDecoder().decode(ArtifactBundleInfo.self, from: data)

        self.info = info
        self.rootDirectory = path
        self.source = source
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
                        source: source,
                        version: artifact.version,
                        manufacturer: .artifactBundle(fileName: fileName)
                    )
                }
        }
    }
}
