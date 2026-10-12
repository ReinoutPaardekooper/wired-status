// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WiredStatus",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WiredStatus", targets: ["WiredStatus"])],
    targets: [
        .target(name: "NetworkCore", publicHeadersPath: "include"),
        .executableTarget(name: "WiredStatus", dependencies: ["NetworkCore"],
                          linkerSettings: [.linkedFramework("AppKit"),
                                           .linkedFramework("SystemConfiguration"),
                                           .linkedFramework("ServiceManagement")]),
        .testTarget(name: "WiredStatusTests", dependencies: ["WiredStatus", "NetworkCore"])
    ]
)
