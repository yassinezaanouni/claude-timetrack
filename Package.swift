// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClaudeTimeTrack",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeTimeTrack",
            path: ".",
            exclude: [
                "Package.swift",
                "project.yml",
                "Info.plist",
                "build_app.sh",
                "README.md",
                "LICENSE",
                "screenshots"
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
