// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSyslog",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_10),
        .tvOS(.v9)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SwiftSyslog",
            targets: ["SwiftSyslog"]),
    ],
    dependencies: [
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SwiftSyslog",
            dependencies: [
                "CocoaAsyncSocket"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SwiftSyslogTests",
            dependencies: ["SwiftSyslog"]),
    ]
)
