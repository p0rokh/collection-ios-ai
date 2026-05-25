// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CellExplosionKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "CellExplosionKit", targets: ["CellExplosionKit"]),
    ],
    targets: [
        .target(
            name: "CellExplosionKit",
            path: "Sources/CellExplosionKit"
        ),
        .testTarget(
            name: "CellExplosionKitTests",
            dependencies: ["CellExplosionKit"],
            path: "Tests/CellExplosionKitTests"
        ),
    ]
)
