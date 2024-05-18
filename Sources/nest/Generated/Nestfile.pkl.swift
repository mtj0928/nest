// Code generated from Pkl module `Nestfile`. DO NOT EDIT.
import PklSwift

public enum Nestfile {}

extension Nestfile {
    public struct Module: PklRegisteredType, Decodable, Hashable {
        public static var registeredIdentifier: String = "Nestfile"

        public var nestPath: String?

        public var artifacts: [AnyHashable?]

        public init(nestPath: String?, artifacts: [AnyHashable?]) {
            self.nestPath = nestPath
            self.artifacts = artifacts
        }

        public init(from decoder: Decoder) throws {
            let dec = try decoder.container(keyedBy: PklCodingKey.self)
            let nestPath = try dec.decode(String?.self, forKey: PklCodingKey(string: "nestPath"))
            let artifacts = try dec.decode([PklSwift.PklAny].self, forKey: PklCodingKey(string: "artifacts"))
                    .map { $0.value as! AnyHashable? }
            self = Module(nestPath: nestPath, artifacts: artifacts)
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