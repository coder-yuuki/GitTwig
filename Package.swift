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
    targets: [
        .executableTarget(
            name: "GitTwig",
            path: "GitTwig"
        )
    ]
)
