// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VisualDataTransfer",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "VisualDataTransferKit", targets: ["VisualDataTransferKit"]),
        .executable(name: "VisualDataTransferDemo", targets: ["VisualDataTransferDemo"]),
    ],
    targets: [
        .target(
            name: "VDTCoreC",
            path: "core",
            exclude: [
                "tests",
                "build",
                "CMakeLists.txt",
            ],
            publicHeadersPath: "ffi/include",
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-std=c++20"]),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        .target(
            name: "VisualDataTransferKit",
            dependencies: ["VDTCoreC"],
            path: "ios/Sources/VisualDataTransferKit"
        ),
        .executableTarget(
            name: "VisualDataTransferDemo",
            dependencies: ["VisualDataTransferKit"],
            path: "ios/Demo"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
