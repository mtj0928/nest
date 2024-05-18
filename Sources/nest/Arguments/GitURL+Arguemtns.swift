import ArgumentParser
import Foundation
import NestKit

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
        if let url = URL(string: argument),
           url.pathExtension == "zip" {
            self = .artifactBundle(url)
        } else if let gitURL = GitURL.parse(string: argument) {
            self = .git(gitURL)
        } else {
            return nil
        }
    }
}
