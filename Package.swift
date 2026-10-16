// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FrictionBudget",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FrictionBudget", targets: ["FrictionBudget"])
    ],
    targets: [
        .target(name: "FrictionBudget"),
        .testTarget(name: "FrictionBudgetTests", dependencies: ["FrictionBudget"])
    ]
)
