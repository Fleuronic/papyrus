// swift-tools-version:6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "papyrus",
    platforms: [
		.iOS(.v13),
		.macOS(.v10_15),
		.tvOS(.v13),
		.watchOS(.v6)
    ],
    products: [
        .executable(name: "Example", targets: ["Example"]),
        .library(name: "Papyrus", targets: ["Papyrus"]),
        .library(name: "PapyrusCore", targets: ["PapyrusCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "510.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.1.0"),
    ],
    targets: [
        
        // MARK: Demo
        
        .executableTarget(
            name: "Example",
            dependencies: ["Papyrus"],
            path: "Example"
        ),
        
        // MARK: Libraries
        
        .target(
            name: "Papyrus",
            dependencies: [
                .byName(name: "PapyrusCore")
            ],
            path: "Papyrus"
        ),
        .target(
            name: "PapyrusCore",
            dependencies: [
                .byName(name: "PapyrusPlugin"),
            ],
            path: "PapyrusCore/Sources"
        ),
        
        // MARK: Plugin
        
        .macro(
            name: "PapyrusPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "PapyrusPlugin/Sources"
        ),
        
        // MARK: Tests
        
        .testTarget(
            name: "PapyrusCoreTests",
            dependencies: ["PapyrusCore"],
            path: "PapyrusCore/Tests"
        ),
        .testTarget(
            name: "PapyrusPluginTests",
            dependencies: [
                "PapyrusPlugin",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ],
            path: "PapyrusPlugin/Tests"
        )
    ],
	swiftLanguageModes: [.v6]
)
