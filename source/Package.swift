// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Orbit", targets: ["Orbit"])],
    targets: [
        .target(name: "OrbitCore"),
        .executableTarget(name: "Orbit", dependencies: ["OrbitCore"]),
        .executableTarget(name: "OrbitCoreChecks", dependencies: ["OrbitCore"], path: "Tests/OrbitCoreTests")
    ]
)
