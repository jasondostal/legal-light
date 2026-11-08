// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HoursCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HoursCore", targets: ["HoursCore"])],
    targets: [
        .target(name: "HoursCore", resources: [.copy("Resources")]),
        .testTarget(name: "HoursCoreTests", dependencies: ["HoursCore"], resources: [.copy("Fixtures")]),
    ]
)
