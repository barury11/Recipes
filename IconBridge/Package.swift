// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "IconBridgeCore", platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "IconBridgeCore", targets: ["IconBridgeCore"])],
    targets: [.target(name: "IconBridgeCore", path: "Core"),
              .testTarget(name: "IconBridgeCoreTests", dependencies: ["IconBridgeCore"], path: "Tests")])
