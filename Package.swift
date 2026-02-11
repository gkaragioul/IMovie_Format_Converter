// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VideoConverterOsx",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "VideoConverterCore",
            targets: ["VideoConverterCore"]
        ),
        .executable(
            name: "VideoConverterOsxApp",
            targets: ["VideoConverterOsxApp"]
        )
    ],
    targets: [
        .target(
            name: "VideoConverterCore"
        ),
        .executableTarget(
            name: "VideoConverterOsxApp",
            dependencies: ["VideoConverterCore"]
        ),
        .testTarget(
            name: "VideoConverterCoreTests",
            dependencies: ["VideoConverterCore"]
        )
    ]
)
