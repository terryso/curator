import XCTest
@testable import Curator

/// ATDD Tests for Story 1.1 - Build Configuration
///
/// These tests verify AC1: 项目成功构建
/// - 项目成功编译，无错误
/// - 目标平台为 macOS 15.0，架构 arm64
final class BuildConfigurationTests: XCTestCase {

    // MARK: - AC1: 项目成功构建

    /// [P0] 验证 Xcode 项目可以成功编译
    func testXcodeProjectBuildsSuccessfully() throws {
        // 测试能运行即证明编译通过

        // 验证 CuratorApp.swift 入口点存在于源码目录
        let sourceRoot = try Self.getSourceRoot()
        let appSourceURL = sourceRoot
            .appendingPathComponent("Curator")
            .appendingPathComponent("CuratorApp.swift")
        let appSourceExists = FileManager.default.fileExists(atPath: appSourceURL.path)
        XCTAssertTrue(appSourceExists, "CuratorApp.swift 入口文件应该存在于 Curator/ 目录下")

        // 验证部署目标为 macOS 15.0
        let macOS15_0 = OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        XCTAssertTrue(ProcessInfo.processInfo.isOperatingSystemAtLeast(macOS15_0),
            "运行平台应为 macOS 15.0 或更高版本")

        // 验证架构为 arm64
        #if !arch(arm64)
        XCTFail("目标架构应为 arm64 (Apple Silicon)")
        #endif
    }

    // MARK: - Helpers

    /// Get the project source root from the SRCROOT embedded in the host app's Info.plist.
    static func getSourceRoot() throws -> URL {
        // SRCROOT is embedded in the host app's Info.plist via $(SRCROOT) build setting.
        // This is used by ATDD tests to locate project files (directory structure, entitlements, etc.).
        let hostBundle = Bundle.main
        if let srcroot = hostBundle.infoDictionary?["SRCROOT"] as? String {
            return URL(fileURLWithPath: srcroot)
        }
        // Fallback: try environment variable
        if let srcroot = ProcessInfo.processInfo.environment["SRCROOT"] {
            return URL(fileURLWithPath: srcroot)
        }
        throw TestError.sourceRootNotFound
    }

    enum TestError: Error, LocalizedError {
        case sourceRootNotFound
        var errorDescription: String? {
            "无法定位项目源码根目录 (SRCROOT)。确保 Info.plist 包含 SRCROOT 键。"
        }
    }
}
