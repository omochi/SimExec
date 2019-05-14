// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SimExec",
    platforms: [.macOS(.v10_14)],
    dependencies: [
        .package(url: "https://github.com/omochi/FineJSON", from: "1.13.0"),
        .package(url: "https://github.com/Azoy/Sword.git", .revision("19d7815cf499bb2b32055ef4cd74b7d0314b8ef5"))
    ],
    targets: [
        .target(name: "SimExec", dependencies: ["FineJSON"]),
        .testTarget(name: "SimExecTests", dependencies: ["SimExec"]),
        .target(name: "sim-exec", dependencies: ["SimExec"]),
        .target(name: "SimExecAgent", dependencies: ["SimExec", "FineJSON"]),
        .target(name: "sim-exec-agent", dependencies: ["SimExecAgent"]),
        .testTarget(name: "SimExecAgentTests", dependencies: ["SimExecAgent"]),
        .target(name: "SimExecDiscord", dependencies: ["SimExecAgent", "Sword"]),
        .target(name: "sim-exec-discord", dependencies: ["SimExecDiscord"])
    ]
)
