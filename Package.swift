// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MDEditor",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MDEditor", targets: ["MDEditor"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "MDEditor",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        )
    ]
)
