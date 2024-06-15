import ArgumentParser
import Foundation
import NestKit
import UniformTypeIdentifiers

extension GitURL: ExpressibleByArgument {
    public init?(argument: String) {
        guard let url = GitURL.parse(string: argument) else { return nil }
        self = url
    }
}

enum InstallTarget: ExpressibleByArgument {
    case git(GitURL)
    case artifactBundle(URL)

    init?(argument: String) {
        guard let url = URL(string: argument) else { return nil }
        
        if let utType = UTType(filenameExtension: url.pathExtension), utType.conforms(to: .zip) {
            self = .artifactBundle(url)
        } else if let gitURL = GitURL.parse(string: argument) {
            self = .git(gitURL)
        } else {
            return nil
        }
    }
}
