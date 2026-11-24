import Foundation
import Testing
@testable import ColorShift

struct AppConfigTests {
    @Test func urlSchemeMatchesInfoPlist() throws {
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains(AppConfig.urlScheme))
    }

    @Test func bundleIDMatchesBuildSetting() {
        #expect(Bundle.main.bundleIdentifier == AppConfig.bundleID)
    }
}
