// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cinema-engine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "cinema-engine", targets: ["CinemaEngineCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "CinemaEngineCLI",
            dependencies: [
                "AudioEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CinemaEngineCLI",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/CinemaEngineCLI/Info.plist"
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
