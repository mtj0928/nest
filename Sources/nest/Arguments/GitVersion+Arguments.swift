import ArgumentParser
import NestKit

extension GitVersion: ExpressibleByArgument {
    public init?(argument: String) {
        self = .tag(argument)
    }

    public var defaultValueDescription: String {
        description
    }
}
