// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Tjuvkik",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Tjuvkik", targets: ["Tjuvkik"]),
    ],
    targets: [
        .target(name: "TjuvkikCore"),
        .executableTarget(name: "Tjuvkik", dependencies: ["TjuvkikCore"]),
        .testTarget(name: "TjuvkikCoreTests", dependencies: ["TjuvkikCore"]),
    ]
)
