// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HotkeySpy",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HotkeySpyCore"),
        .executableTarget(
            name: "HotkeySpy",
            dependencies: ["HotkeySpyCore"]
        ),
        .testTarget(
            name: "HotkeySpyCoreTests",
            dependencies: ["HotkeySpyCore"]
        ),
    ]
)
