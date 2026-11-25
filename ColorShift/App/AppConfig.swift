import Foundation

/// The single home for values that depend on owner decisions (prd.md §0 Rules).
/// Each placeholder is marked with the HUMAN task that replaces it.
nonisolated enum AppConfig {
    /// Bundle ID (H-01). Keep in sync with `PRODUCT_BUNDLE_IDENTIFIER` in project.yml.
    static let bundleID = "com.kierandelpasqua.colorshift"

    /// TODO(H-03): the published web app's base URL, used for share links (ios.md §12).
    static let webBaseURL = URL(string: "https://example.com/")!

    /// Privacy policy (H-07): `docs/privacy-policy.md`, served by GitHub Pages from `main` → `/docs`.
    /// TODO(H-07): live once Pages is enabled for the repo.
    static let privacyPolicyURL = URL(string: "https://kierandelpasqua.github.io/color_shift_simplified_ios/privacy-policy.html")!

    /// Custom URL scheme for opening pairs in the app (ios.md §12). Registered in Info.plist.
    static let urlScheme = "colorshift"
}
