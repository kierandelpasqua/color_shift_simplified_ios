import Foundation

/// The single home for values that depend on owner decisions (prd.md §0 Rules).
/// Each placeholder is marked with the HUMAN task that replaces it.
nonisolated enum AppConfig {
    /// TODO(H-01): replace with the real bundle ID (also `PRODUCT_BUNDLE_IDENTIFIER` in project.yml).
    static let bundleID = "com.example.colorshift"

    /// TODO(H-03): the published web app's base URL, used for share links (ios.md §12).
    static let webBaseURL = URL(string: "https://example.com/")!

    /// TODO(H-07): the hosted privacy policy URL.
    static let privacyPolicyURL = URL(string: "https://example.com/privacy")!

    /// Custom URL scheme for opening pairs in the app (ios.md §12). Registered in Info.plist.
    static let urlScheme = "colorshift"
}
