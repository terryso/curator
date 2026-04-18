import XCTest
@testable import Curator

/// ATDD Tests for Story 1.1 - 目录结构
///
/// These tests verify AC2: Feature-based 目录结构已创建
final class DirectoryStructureTests: XCTestCase {

    // MARK: - AC2: Feature-based 目录结构

    /// [P1] 验证 Feature-based 目录结构完整
    func testFeatureBasedDirectoryStructureExists() throws {
        let fileManager = FileManager.default
        let sourceRoot = try BuildConfigurationTests.getSourceRoot()
        let curatorDir = sourceRoot.appendingPathComponent("Curator")

        let expectedDirectories: [String] = [
            "App",
            "Core",
            "Features",
            "Infrastructure",
            "Resources",
            "Core/Agent",
            "Core/Operations",
            "Core/Models",
            "Core/Errors",
            "Core/Extensions",
            "Infrastructure/PhotoKit",
            "Infrastructure/LLM",
            "Infrastructure/Analysis",
            "Infrastructure/Storage",
            "Infrastructure/SDKTools",
            "Infrastructure/Update",
        ]

        for dirPath in expectedDirectories {
            let fullURL = curatorDir.appendingPathComponent(dirPath)
            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: fullURL.path, isDirectory: &isDir)
            XCTAssertTrue(exists && isDir.boolValue,
                "目录应存在: Curator/\(dirPath)")
        }
    }
}
