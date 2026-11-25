import Foundation

/// One bundled photo (PM §14). `id` is the web's Unsplash image-CDN name (`photo-<…>`), which is also the
/// bundled file name (`Resources/Photos/<id>.jpg`, H-05).
nonisolated struct Photo: Identifiable, Hashable, Sendable {
    let id: String
    let theme: Theme
    let alt: String
    /// Hand-picked pair shown before the derived pair (PM §8.9).
    let fallback: ColorPair
    /// Width / height, measured from the bundled file (T-014; the web hand-enters approximate values).
    let aspect: Double
    let photographer: String
    /// Unsplash username, without `@`.
    let handle: String
    /// The photo's unsplash.com page. Optional: credits link to the photographer's profile, as on the web.
    var unsplashPageURL: URL?

    /// Unsplash attribution links (ios.md §13): the photographer's profile and Unsplash, both tagged with
    /// the referral parameters Unsplash asks API-style apps to add.
    var photographerURL: URL { Self.referral("https://unsplash.com/@\(handle)") }
    static let unsplashURL = referral("https://unsplash.com/")

    static let referralQuery = [URLQueryItem(name: "utm_source", value: "color_shift"),
                                URLQueryItem(name: "utm_medium", value: "referral")]

    private static func referral(_ string: String) -> URL {
        var components = URLComponents(string: string)!
        components.queryItems = referralQuery
        return components.url!
    }

    var fileName: String { "\(id).jpg" }

    /// The exact URL the web app loads (and puts in its Markdown export, PM §14).
    var webImageURL: URL {
        URL(string: "https://images.unsplash.com/\(id)?auto=format&fit=crop&w=1800&q=88")!
    }
}
