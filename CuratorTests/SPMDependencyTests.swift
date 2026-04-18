import XCTest
@testable import Curator

/// ATDD Tests for Story 1.1 - SPM 依赖配置
///
/// These tests verify AC2: SPM 依赖正确配置
final class SPMDependencyTests: XCTestCase {

    // MARK: - AC2: SPM 依赖正确配置

    /// [P0] 验证 OpenAgentSDKSwift 依赖已正确解析
    func testOpenAgentSDKSwiftDependencyResolved() throws {
        let sourceRoot = try BuildConfigurationTests.getSourceRoot()
        let localPackageURL = sourceRoot
            .appendingPathComponent("Packages")
            .appendingPathComponent("OpenAgentSDKSwift")
            .appendingPathComponent("Package.swift")

        let localPackageExists = FileManager.default.fileExists(atPath: localPackageURL.path)
        XCTAssertTrue(localPackageExists,
            "OpenAgentSDKSwift 本地包应存在于 Packages/OpenAgentSDKSwift/ 目录下")
    }

    /// [P0] 验证 Sparkle 2 依赖已正确解析
    func testSparkleDependencyResolved() throws {
        let sourceRoot = try BuildConfigurationTests.getSourceRoot()
        let packageResolvedURL = sourceRoot
            .appendingPathComponent("Curator.xcodeproj")
            .appendingPathComponent("project.xcworkspace")
            .appendingPathComponent("xcshareddata")
            .appendingPathComponent("swiftpm")
            .appendingPathComponent("Package.resolved")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: packageResolvedURL.path),
            "Package.resolved 文件应存在"
        )

        let packageData = try Data(contentsOf: packageResolvedURL)
        let packageJSON = try JSONSerialization.jsonObject(with: packageData) as? [String: Any]
        let pins = packageJSON?["pins"] as? [[String: Any]] ?? []

        let hasSparkle = pins.contains { pin in
            (pin["location"] as? String)?.contains("sparkle-project/Sparkle") == true
                || (pin["identity"] as? String) == "sparkle"
        }
        XCTAssertTrue(hasSparkle, "Package.resolved 应包含 Sparkle 依赖")

        // 验证 Sparkle 版本在 2.0.0..<3.0.0 范围内
        let sparklePin = pins.first { pin in
            (pin["identity"] as? String) == "sparkle"
                || (pin["location"] as? String)?.contains("sparkle-project/Sparkle") == true
        }
        let state = sparklePin?["state"] as? [String: Any]
        let version = state?["version"] as? String ?? "0.0.0"
        let sparkleVersion = version.split(separator: ".").compactMap { Int($0) }
        if sparkleVersion.count >= 2 {
            XCTAssertTrue(sparkleVersion[0] == 2,
                "Sparkle 主版本号应为 2（版本范围 2.0.0..<3.0.0），当前版本: \(version)")
        }
    }
}
