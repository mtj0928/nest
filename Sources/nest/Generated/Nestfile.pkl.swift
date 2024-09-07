// Code generated from Pkl module `Nestfile`. DO NOT EDIT.
import PklSwift

public enum Nestfile {}

extension Nestfile {
    public enum Target: Decodable, Hashable {
        case repository(Repository)
        case zipUrl(ZipUrl)

        public init(from decoder: Decoder) throws {
            let decoded = try decoder.singleValueContainer().decode(PklSwift.PklAny.self).value
            switch decoded {
            case let decoded as Repository:
                self = Target.repository(decoded)
            case let decoded as ZipUrl:
                self = Target.zipUrl(decoded)
            default:
                throw DecodingError.typeMismatch(
                    Target.self,
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected type Target, but got \(String(describing: decoded))"
                    )
                )
            }
        }
    }

    public struct Module: PklRegisteredType, Decodable, Hashable {
        public static var registeredIdentifier: String = "Nestfile"

        public var nestPath: String?

        public var targets: [Target]

        public init(nestPath: String?, targets: [Target]) {
            self.nestPath = nestPath
            self.targets = targets
        }
    }

    public struct Repository: PklRegisteredType, Decodable, Hashable {
        public static var registeredIdentifier: String = "Nestfile#Repository"

        public var reference: String

        public var version: String?

        public init(reference: String, version: String?) {
            self.reference = reference
            self.version = version
        }
    }

    public typealias ZipUrl = String

    /// Load the Pkl module at the given source and evaluate it into `Nestfile.Module`.
    ///
    /// - Parameter source: The source of the Pkl module.
    public static func loadFrom(source: ModuleSource) async throws -> Nestfile.Module {
        try await PklSwift.withEvaluator { evaluator in
            try await loadFrom(evaluator: evaluator, source: source)
        }
    }

    /// Load the Pkl module at the given source and evaluate it with the given evaluator into
    /// `Nestfile.Module`.
    ///
    /// - Parameter evaluator: The evaluator to use for evaluation.
    /// - Parameter source: The module to evaluate.
    public static func loadFrom(
        evaluator: PklSwift.Evaluator,
        source: PklSwift.ModuleSource
    ) async throws -> Nestfile.Module {
        try await evaluator.evaluateModule(source: source, as: Module.self)
    }
}
