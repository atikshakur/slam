// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Slam",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Slam", targets: ["Slam"])],
    targets: [
        .target(name: "SlamCore"),
        .executableTarget(name: "Slam", dependencies: ["SlamCore"]),
        .executableTarget(name: "SlamCoreTests", dependencies: ["SlamCore"], path: "Tests/SlamCoreTests")
    ]
)
