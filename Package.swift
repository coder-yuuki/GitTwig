// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GitTwig",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GitTwig", targets: ["GitTwig"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1")
    ],
    targets: [
        .executableTarget(
            name: "GitTwig",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "GitTwig",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
