import ArgumentParser
import NestKit

extension ExcludedVersion: ExpressibleByArgument {
    public init?(argument: String) {
        let split = argument.split(separator: "@")
        guard split.count == 1 || split.count == 2 else { return nil }
        self = .init(reference: String(split[0]), target: split.count == 2 ? String(split[1]) : nil)
    }
}
