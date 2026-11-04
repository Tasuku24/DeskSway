// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskSway",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DeskSway", targets: ["DeskSway"])],
    targets: [
        .target(name: "DeskSwayCore"),
        .executableTarget(name: "DeskSway", dependencies: ["DeskSwayCore"]),
        .testTarget(name: "DeskSwayCoreTests", dependencies: ["DeskSwayCore", "DeskSway"])
    ]
)
