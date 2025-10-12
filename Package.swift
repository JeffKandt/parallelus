// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "agent-process-demo",
    products: [
        .library(name: "agent-process-demo", targets: ["agent-process-demo"])
    ],
    targets: [
        .target(name: "agent-process-demo"),
        .testTarget(name: "agent-process-demoTests", dependencies: ["agent-process-demo"])
    ]
)
