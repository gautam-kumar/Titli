// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TitliCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TitliCore", targets: ["TitliCore"])],
    targets: [
        .target(name: "TitliCore"),
        .testTarget(name: "TitliCoreTests", dependencies: ["TitliCore"]),
    ]
)
