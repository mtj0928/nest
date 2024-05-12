import Foundation

extension SwiftCommand {
    public func description() async throws -> SwiftPackageDescription {
        let json = try await run("package", "describe", "--type", "json")
        return try JSONDecoder().decode(SwiftPackageDescription.self, from: json.data(using: .utf8)!)
    }
}

public struct SwiftPackageDescription: Codable {
    public var products: [Product]

    public init(products: [Product]) {
        self.products = products
    }

    public var executableNames: [String] {
        products.compactMap { product in
            product.type.keys.contains("executable") ? product.name : nil
        }
    }
}

extension SwiftPackageDescription {
    public struct Product: Codable {
        public var name: String
        public var type: [String: String?]

        public init(name: String, type: [String : String?]) {
            self.name = name
            self.type = type
        }
    }
}
