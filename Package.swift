// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "nest",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "nest", targets: ["nest"]),
        .library(name: "NestKit", targets: ["NestKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.1"),
    ],
    targets: [
        .executableTarget(name: "nest", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "Logging", package: "swift-log"),
            "NestKit"
        ]),

        .target(name: "NestKit", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "Rainbow",
            "ZIPFoundation",
        ]),

        // MARK: - Test targets
        .testTarget(name: "NestTests", dependencies: [
            "nest",
            .product(name: "Testing", package: "swift-testing")
        ]),
        .testTarget(name: "NestKitTests", dependencies: [
            "NestKit",
            .product(name: "Testing", package: "swift-testing")
        ]),
    ]
)

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("StrictConcurrency"),
    .unsafeFlags(["-enable-actor-data-race-checks"])
]

for target in package.targets {
    target.swiftSettings = target.swiftSettings ?? []
    target.swiftSettings?.append(contentsOf: swiftSettings)
}
