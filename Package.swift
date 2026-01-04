// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HabitTracker",
    platforms: [
        .iOS(.v17),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "HabitTracker",
            targets: ["HabitTracker"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0")
    ],
    targets: [
        .target(
            name: "HabitTracker",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "HabitTracker",
            exclude: ["Tests"]
        ),
        .testTarget(
            name: "HabitTrackerTests",
            dependencies: ["HabitTracker"],
            path: "HabitTracker/Tests"
        )
    ]
)
