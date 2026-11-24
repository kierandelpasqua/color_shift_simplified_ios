import Foundation

/// One bundled photo (PM §14). `id` is the web's Unsplash image-CDN name (`photo-<…>`), which is also the
/// bundled file name (`Resources/Photos/<id>.jpg`, H-05).
nonisolated struct Photo: Identifiable, Hashable, Sendable {
    let id: String
    let theme: Theme
    let alt: String
    /// Hand-picked pair shown before the derived pair (PM §8.9).
    let fallback: ColorPair
    /// Width / height. Hand-entered on the web; replaced by values measured from the bundled files (T-014).
    let aspect: Double
    let photographer: String
    /// Unsplash username, without `@`.
    let handle: String
    /// The photo's unsplash.com page. Unknown until H-05 maps each CDN name to its page.
    var unsplashPageURL: URL?

    var fileName: String { "\(id).jpg" }

    /// The exact URL the web app loads (and puts in its Markdown export, PM §14).
    var webImageURL: URL {
        URL(string: "https://images.unsplash.com/\(id)?auto=format&fit=crop&w=1800&q=88")!
    }
}
