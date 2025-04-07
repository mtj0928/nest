import ArgumentParser
import NestKit

extension ExcludedTarget: ExpressibleByArgument {
    public init?(argument: String) {
        let split = argument.split(separator: "@")
        guard split.count == 1 || split.count == 2 else { return nil }
        self = .init(reference: String(split[0]), version: split.count == 2 ? String(split[1]) : nil)
    }
}
