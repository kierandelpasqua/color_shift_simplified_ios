import Foundation
import Testing
@testable import ColorShift

/// ios.md §16: no tracking, no collected data, UserDefaults (haptics toggle) with reason CA92.1.
struct PrivacyManifestTests {
    @Test func manifestIsBundledAndDeclaresOnlyUserDefaults() throws {
        let url = try #require(Bundle(for: AppModel.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
                               "PrivacyInfo.xcprivacy is not in the app bundle")
        let plist = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let apis = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(apis.count == 1)
        #expect(apis.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(apis.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
