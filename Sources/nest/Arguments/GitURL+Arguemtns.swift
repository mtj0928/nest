import ArgumentParser
import NestKit

extension GitURL: ExpressibleByArgument {
    public init?(argument: String) {
        guard let url = GitURL.parse(string: argument) else { return nil }
        self = url
    }
}
