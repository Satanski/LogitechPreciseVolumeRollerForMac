// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LogitechPreciseVolumeRollerForMac",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "LogitechPreciseVolumeRoller", targets: ["LogitechPreciseVolumeRoller"])
    ],
    targets: [
        // Core logic module
        .target(
            name: "LogitechPreciseVolumeRoller",
            path: "Sources/LogitechPreciseVolumeRoller"
        ),
        // Main App
        .executableTarget(
            name: "LogitechPreciseVolumeRollerForMac",
            dependencies: ["LogitechPreciseVolumeRoller"],
            path: "Sources/LogitechPreciseVolumeRollerApp"
        ),
        // Test runner
        .executableTarget(
            name: "VolumeRollerTestsRunner",
            dependencies: ["LogitechPreciseVolumeRoller"],
            path: "Tests/VolumeRollerTestsRunner"
        )
    ]
)
