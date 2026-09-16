// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cinema-engine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CinemaEngine", targets: ["CinemaEngineApp"])
    ],
    targets: [
        .executableTarget(
            name: "CinemaEngineApp",
            dependencies: ["AudioEngine"],
            path: "Sources/CinemaEngineApp",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/CinemaEngineApp/Info.plist"
                ])
            ]
        ),
        .target(
            name: "AudioEngine",
            dependencies: [],
            path: "Sources/AudioEngine",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AudioUnit"),
                .linkedFramework("Accelerate")
            ]
        )
    ]
)
