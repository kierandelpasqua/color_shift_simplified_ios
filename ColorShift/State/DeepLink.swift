import Foundation

/// A share link's state: `?fg=RRGGBB&bg=RRGGBB&photo=N` (PM §14, ios.md §12).
/// Accepted forms: `colorshift://pair?…` and `https://<web host>/…?…` (the host from `AppConfig`).
nonisolated struct DeepLink: Hashable, Sendable {
    /// Each color is nil when missing or not exactly 6 hex digits (the web's `/^[\da-f]{6}$/i`).
    var foreground: SRGB8?
    var background: SRGB8?
    /// Full-catalog index, or nil when present but invalid (the photo is left unchanged).
    /// A **missing or empty** `photo` means 0, like the web (`Number(null) === 0`).
    var photoIndex: Int?

    var hasBothColors: Bool { foreground != nil && background != nil }

    init(foreground: SRGB8?, background: SRGB8?, photoIndex: Int?) {
        self.foreground = foreground
        self.background = background
        self.photoIndex = photoIndex
    }

    /// Returns nil for URLs that aren't Color Shift links.
    init?(url: URL, webBaseURL: URL = AppConfig.webBaseURL, catalogCount: Int = PhotoCatalog.all.count) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased() else { return nil }
        switch scheme {
        case AppConfig.urlScheme:
            guard components.host?.lowercased() == "pair" else { return nil }
        case "https":
            guard let host = components.host?.lowercased(), host == webBaseURL.host()?.lowercased() else { return nil }
        default:
            return nil
        }
        // URLSearchParams.get returns the first value for a repeated key.
        func value(_ name: String) -> String? { components.queryItems?.first { $0.name == name }?.value }

        foreground = Self.color(value("fg"))
        background = Self.color(value("bg"))
        photoIndex = Self.index(value("photo"), count: catalogCount)
    }

    private static func color(_ raw: String?) -> SRGB8? {
        // Exactly 6 hex digits: no "#", unlike SRGB8(hex:).
        guard let raw, raw.utf8.count == 6, !raw.hasPrefix("#") else { return nil }
        return SRGB8(hex: raw)
    }

    /// Strict on iOS: plain decimal digits only. (The web's `Number()` also accepts "1.0", "0x3", " 3 ",
    /// "1e1"; those are ignored here.) Missing or empty → 0, as on the web.
    private static func index(_ raw: String?, count: Int) -> Int? {
        guard let raw, !raw.isEmpty else { return 0 }
        guard raw.utf8.allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }),
              let n = Int(raw), (0..<count).contains(n) else { return nil }
        return n
    }
}
