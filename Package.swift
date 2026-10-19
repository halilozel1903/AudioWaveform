// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AudioWaveform",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        // macOS only so `swift test` runs on CI; the views are made for iPhone and Apple Watch.
        .macOS(.v14),
    ],
    products: [
        .library(name: "AudioWaveform", targets: ["AudioWaveform"]),
        .library(name: "AudioWaveformUI", targets: ["AudioWaveformUI"]),
    ],
    targets: [
        .target(name: "AudioWaveform"),
        .target(name: "AudioWaveformUI", dependencies: ["AudioWaveform"]),
        .testTarget(name: "AudioWaveformTests", dependencies: ["AudioWaveform"]),
    ]
)
