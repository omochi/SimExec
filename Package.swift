// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SimExec",
    platforms: [.macOS(.v10_14)],
    products: [
        .library(name: "SimExec", targets: ["SimExec"]),
        .executable(name: "sim-exec", targets: ["sim-exec"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "SimExec", dependencies: []),
        .target(name: "sim-exec", dependencies: ["SimExec"]),
        .testTarget(name: "SimExecTests", dependencies: ["SimExec"]),
    ]
)
