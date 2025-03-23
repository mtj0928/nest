import Foundation

extension SwiftCommand {
    public func description() async throws -> SwiftPackageDescription {
        let json = try await run("package", "describe", "--type", "json")

        // WORKAROUND
        // The outputs of describe command sometime contains warning like this message.
        // https://github.com/swiftlang/swift-package-manager/blob/db9fef21d000dd475816951d52f8d32077939e81/Sources/PackageLoading/TargetSourcesBuilder.swift#L193
        // To address the issue, string until "{" is removed here.
        let cleanedJson = removePrefixUpToFirstBrace(json)
        return try JSONDecoder().decode(SwiftPackageDescription.self, from: cleanedJson.data(using: .utf8)!)
    }

    private func removePrefixUpToFirstBrace(_ input: String) -> String {
        if let index = input.firstIndex(of: "{") {
            String(input[index...])
        } else {
            input
        }
    }
}

public struct SwiftPackageDescription: Decodable {
    public var products: [Product]

    public init(products: [Product]) {
        self.products = products
    }

    public var executableNames: [String] {
        products.compactMap { product in
            product.type == .executable ? product.name : nil
        }
    }
}

extension SwiftPackageDescription {
    public struct Product: Decodable, Equatable {
        public var name: String
        public var type: ProductType

        public init(name: String, type: ProductType) {
            self.name = name
            self.type = type
        }
    }

    // This enum refers https://github.com/apple/swift-package-manager/blob/main/Sources/PackageModel/Product.swift
    public enum ProductType: Equatable, Hashable, Sendable, Decodable {
        public enum LibraryType: String, Codable, Sendable {
            case `static`
            case `dynamic`
            case automatic
        }

        case library(LibraryType)
        case executable
        case snippet
        case plugin
        case test
        case `macro`

        enum CodingKeys: CodingKey {
            case library
            case executable
            case snippet
            case plugin
            case test
            case macro
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            guard let key = values.allKeys.first(where: values.contains) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Did not find a matching key"))
            }
            switch key {
            case .library:
                var unkeyedValues = try values.nestedUnkeyedContainer(forKey: key)
                let a1 = try unkeyedValues.decode(ProductType.LibraryType.self)
                self = .library(a1)
            case .test: self = .test
            case .executable: self = .executable
            case .snippet: self = .snippet
            case .plugin: self = .plugin
            case .macro: self = .macro
            }
        }
    }
}
