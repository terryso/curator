import XCTest
@testable import Curator

/// ATDD Tests for Story 1.1 - Entitlements 配置
///
/// These tests verify AC3: Entitlements 文件配置正确
final class EntitlementsTests: XCTestCase {

    // MARK: - AC3: Entitlements 文件配置正确

    /// [P0] 验证 Entitlements 文件包含所有必需权限声明
    func testEntitlementsFileContainsRequiredKeys() throws {
        let requiredEntitlements: [String] = [
            "com.apple.security.app-sandbox",
            "com.apple.security.personal-information.photos",
            "com.apple.security.network.client",
            "com.apple.security.keychain",
        ]

        let sourceRoot = try BuildConfigurationTests.getSourceRoot()
        let entitlementsURL = sourceRoot
            .appendingPathComponent("Curator")
            .appendingPathComponent("Curator.entitlements")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: entitlementsURL.path),
            "Curator.entitlements 文件应该存在于 Curator/ 目录下"
        )

        let entitlementsData = try Data(contentsOf: entitlementsURL)
        let plist = try PropertyListSerialization.propertyList(from: entitlementsData, options: [], format: nil)
        let entitlementsDict = try XCTUnwrap(plist as? [String: Any],
            "Entitlements 文件应包含有效的 plist 字典")

        for key in requiredEntitlements {
            let value = entitlementsDict[key]
            XCTAssertNotNil(value, "Entitlements 缺少必需权限: \(key)")
            if let boolValue = value as? Bool {
                XCTAssertTrue(boolValue, "权限 \(key) 应设置为 YES (true)")
            }
        }
    }
}
