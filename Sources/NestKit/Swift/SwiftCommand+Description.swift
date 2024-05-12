import Foundation

extension SwiftCommand {
    public func description() async throws -> SwiftPackageDescription {
        let json = try await run("package", "describe", "--type", "json")
        return try JSONDecoder().decode(SwiftPackageDescription.self, from: json.data(using: .utf8)!)
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
    public struct Product: Decodable {
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
