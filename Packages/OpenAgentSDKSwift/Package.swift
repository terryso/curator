// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenAgentSDKSwift",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "OpenAgentSDKSwift",
            targets: ["OpenAgentSDKSwift"]
        ),
    ],
    targets: [
        .target(
            name: "OpenAgentSDKSwift",
            path: "Sources/OpenAgentSDKSwift"
        ),
    ]
)
