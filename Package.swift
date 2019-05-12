// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SimExec",
    platforms: [.macOS(.v10_14)],
    products: [
        .library(name: "SimExec", targets: ["SimExec"]),
        .executable(name: "sim-exec", targets: ["sim-exec"]),
        .library(name: "SimExecAgent", targets: ["SimExecAgent"])
    ],
    dependencies: [
        .package(url: "https://github.com/omochi/FineJSON", from: "1.10.0")
    ],
    targets: [
        .target(name: "SimExec", dependencies: []),
        .testTarget(name: "SimExecTests", dependencies: ["SimExec"]),
        .target(name: "sim-exec", dependencies: ["SimExec"]),
        .target(name: "SimExecAgent", dependencies: ["SimExec", "FineJSON"]),
        .testTarget(name: "SimExecAgentTests", dependencies: ["SimExecAgent"])
    ]
)
