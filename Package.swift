// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "TrustMe", platforms: [.macOS(.v13)],
    products: [.executable(name: "TrustMe", targets: ["TrustMe"])],
    targets: [
        .executableTarget(name: "TrustMe"), .testTarget(name: "TrustMeTests", dependencies: ["TrustMe"]),
    ])
