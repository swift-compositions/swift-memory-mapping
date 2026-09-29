// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-memory-mapping",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Memory Mapping",
            targets: ["Memory Mapping"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-compositions/swift-kernel.git", branch: "main"),
        .package(
            url: "https://github.com/swift-standards/swift-darwin-standard.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-linux-foundation/swift-linux-standard.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-memory.git",
            branch: "main", traits: ["Lock", "Map", "Shared"]),
        .package(
            url: "https://github.com/swift-molecules/swift-memory-allocation.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-atoms/swift-system.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-test-application.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Memory Mapping",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Memory", package: "swift-memory"),
                .product(
                    name: "Memory Allocation",
                    package: "swift-memory-allocation"
                ),
                .product(
                    name: "Darwin Memory Standard",
                    package: "swift-darwin-standard",
                    condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])
                ),
                .product(
                    name: "Linux Memory Standard",
                    package: "swift-linux-standard",
                    condition: .when(platforms: [.linux])
                ),
                .product(name: "System", package: "swift-system"),
            ]
        ),
        .testTarget(
            name: "Memory Mapping Tests",
            dependencies: [
                "Memory Mapping",
                .product(name: "Kernel Test Support", package: "swift-kernel"),
                .product(name: "Memory", package: "swift-memory"),
                .product(name: "Testing", package: "swift-test-application"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
