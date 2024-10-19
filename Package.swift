// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "nest",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "nest", targets: ["nest"]),
        .library(name: "NestCLI", targets: ["NestCLI"]),
        .library(name: "NestKit", targets: ["NestKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
    ],
    targets: [
        .executableTarget(name: "nest", dependencies: [
            "NestCLI",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),

        .target(name: "NestCLI", dependencies: [
            "NestKit",
            .product(name: "Yams", package: "Yams")
        ]),
        .target(name: "NestTestHelpers", dependencies: ["NestKit"]),
        .target(name: "NestKit", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "Rainbow",
            "ZIPFoundation",
            .product(name: "HTTPTypesFoundation", package: "swift-http-types")
        ]),

        // MARK: - Test targets
        .testTarget(name: "NestTests", dependencies: ["nest"]),
        .testTarget(
            name: "NestCLITests",
            dependencies: ["NestCLI", "NestTestHelpers"],
            exclude: ["Resources/Fixtures"],
            resources: [.copy("Resources/Fixtures")]
        ),
        .testTarget(name: "NestKitTests", dependencies: ["NestKit", "NestTestHelpers"]),
    ]
)
