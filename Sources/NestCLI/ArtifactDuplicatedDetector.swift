import NestKit
import Foundation

public enum ArtifactDuplicatedDetector {

    public static func isAlreadyInstalled(url: GitURL, version: String?, in nestInfo: NestInfo) -> Bool {
        nestInfo.commands.values
            .flatMap { $0 }
            .contains(where: { command in
                guard version == command.version else { return false }

                switch command.manufacturer {
                case .artifactBundle(let sourceInfo):
                    if let repository = sourceInfo.repository {
                        return repository.reference == url
                    }
                    return false
                case .localBuild(let repository):
                    return repository.reference == url
                }
            })
    }

    public static func isAlreadyInstalled(zipURL: URL, in nestInfo: NestInfo) -> Bool {
        nestInfo.commands.values
            .flatMap { $0 }
            .contains(where: { command in
                switch command.manufacturer {
                case .artifactBundle(let sourceInfo):
                    return sourceInfo.zipURL == zipURL
                case .localBuild:
                    return false
                }
            })
    }
}
