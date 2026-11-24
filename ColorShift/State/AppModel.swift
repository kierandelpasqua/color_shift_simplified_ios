import Foundation
import Observation

nonisolated enum ContrastMode: String, CaseIterable, Sendable {
    case wcag = "WCAG"
    case apca = "APCA"
}

nonisolated enum ColorRole: Sendable { case foreground, background }

nonisolated enum HSLChannel: Sendable { case hue, saturation, lightness }

/// All app state and actions, mirroring the web's `App` (PM §6) minus the dev-only motion state.
/// Colors are `SRGB8`; hex, HSL and contrast are derived.
@Observable
final class AppModel {
    var controlsOpen = false
    /// Selected themes in the order they were picked (like the web); empty means All.
    private(set) var selectedThemes: [Theme] = []
    /// Index into `visiblePhotos`.
    private(set) var photoIndex = 0
    var foreground: SRGB8
    var background: SRGB8
    var mode: ContrastMode = .wcag
    var hapticsEnabled: Bool

    /// The photo whose derived pair hasn't been applied yet (nil once applied or skipped).
    private(set) var pendingDerivation: Photo.ID?
    /// After a deep link sets both colors, skip exactly one derivation (PM §8.9 step 1).
    private(set) var preserveLinkedColors = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let webBaseURL: URL
    static let hapticsKey = "hapticsEnabled"

    init(defaults: UserDefaults = .standard, webBaseURL: URL = AppConfig.webBaseURL) {
        self.defaults = defaults
        self.webBaseURL = webBaseURL
        let first = PhotoCatalog.all[0]
        foreground = first.fallback.foreground
        background = first.fallback.background
        hapticsEnabled = defaults.object(forKey: Self.hapticsKey) as? Bool ?? true
        pendingDerivation = first.id
    }

    // MARK: Derived

    var visiblePhotos: [Photo] { PhotoCatalog.visible(for: Set(selectedThemes)) }
    var photo: Photo { visiblePhotos[photoIndex % visiblePhotos.count] }
    /// The photo's position in the full catalog: what share links use (ios.md §14).
    var catalogIndex: Int { PhotoCatalog.catalogIndex(of: photo)! }
    var wcag: Double { ColorMath.contrast(foreground, background) }
    /// Signed APCA Lc (text = foreground).
    var apca: Double { APCA.lc(text: foreground, background: background) }
    var foregroundHSL: HSL { foreground.hsl }
    var backgroundHSL: HSL { background.hsl }

    // MARK: Photos

    /// Moves through the visible photos with wraparound and applies the new photo's fallback pair.
    func navigate(_ direction: Int) {
        let count = visiblePhotos.count
        photoIndex = ((photoIndex + direction) % count + count) % count
        photoChanged()
    }

    /// `nil` is All (clears the selection). Otherwise toggles the theme. Resets to the first visible photo.
    func toggleTheme(_ theme: Theme?) {
        if let theme {
            if let i = selectedThemes.firstIndex(of: theme) {
                selectedThemes.remove(at: i)
            } else {
                selectedThemes.append(theme)
            }
        } else {
            selectedThemes = []
        }
        photoIndex = 0
        photoChanged()
    }

    /// Tap on the photo: closes the open drawer, otherwise shows the next photo (PM §13).
    func photoTapped() {
        if controlsOpen { controlsOpen = false } else { navigate(1) }
    }

    /// Swipe on the photo (≥ 35pt): closes the open drawer, otherwise moves by `direction` (PM §13).
    func photoSwiped(_ direction: Int) {
        if controlsOpen { controlsOpen = false } else { navigate(direction) }
    }

    /// Tap on the specimen: closes the drawer if open (PM §13).
    func specimenTapped() {
        controlsOpen = false
    }

    /// Applies a photo's derived pair (from `PhotoSampler`), or its fallback when derivation failed.
    /// Ignored for a photo that's no longer showing. Skipped once after a deep link set both colors.
    func photoDidDerive(_ pair: ColorPair?, for photoID: Photo.ID) {
        guard photoID == photo.id, pendingDerivation == photoID else { return }
        pendingDerivation = nil
        if preserveLinkedColors {
            preserveLinkedColors = false
            return
        }
        apply(pair ?? photo.fallback)
    }

    private func photoChanged() {
        apply(photo.fallback)
        pendingDerivation = photo.id
        preserveLinkedColors = false
    }

    private func apply(_ pair: ColorPair) {
        foreground = pair.foreground
        background = pair.background
    }

    // MARK: Colors

    /// Sets one HSL channel. Like the web, the color is rebuilt from its integer HSL, so this is only
    /// called when a slider actually moves; setting a channel to its current value changes nothing.
    func setChannel(_ role: ColorRole, _ channel: HSLChannel, _ value: Int) {
        let current = role == .foreground ? foreground : background
        var hsl = current.hsl
        switch channel {
        case .hue:
            let v = min(360, max(0, value)); guard v != hsl.h else { return }; hsl.h = v
        case .saturation:
            let v = min(100, max(0, value)); guard v != hsl.s else { return }; hsl.s = v
        case .lightness:
            let v = min(100, max(0, value)); guard v != hsl.l else { return }; hsl.l = v
        }
        let next = SRGB8(hsl: hsl)
        if role == .foreground { foreground = next } else { background = next }
    }

    /// Tunes the foreground's lightness toward `target` (4.5 or 7). Returns whether it got there.
    @discardableResult
    func jump(to target: Double) -> Bool {
        let result = ColorMath.tune(foreground, against: background, target: target)
        foreground = result.color
        return result.reachedTarget
    }

    func swap() {
        (foreground, background) = (background, foreground)
    }

    // MARK: Links and export

    /// Restores a shared pair and photo. Valid colors are applied individually; when **both** are valid,
    /// the next derivation is skipped so the link's pair is kept (PM §14).
    func apply(deepLink link: DeepLink) {
        if let index = link.photoIndex {
            // The link's index is a full-catalog position, so clear any filter first.
            let changed = !selectedThemes.isEmpty || index != catalogIndex
            selectedThemes = []
            photoIndex = index
            if changed { photoChanged() }
        }
        if let fg = link.foreground { foreground = fg }
        if let bg = link.background { background = bg }
        // Only a pending derivation can overwrite the link's colors.
        preserveLinkedColors = link.hasBothColors && pendingDerivation != nil
    }

    @discardableResult
    func apply(deepLink url: URL) -> Bool {
        guard let link = DeepLink(url: url, webBaseURL: webBaseURL) else { return false }
        apply(deepLink: link)
        return true
    }

    /// The web's share URL: `<web base>?fg=RRGGBB&bg=RRGGBB&photo=N` with the full-catalog index.
    var shareURL: URL {
        var components = URLComponents(url: webBaseURL, resolvingAgainstBaseURL: false)!
        var items = (components.queryItems ?? []).filter { !["fg", "bg", "photo"].contains($0.name) }
        items += [
            URLQueryItem(name: "fg", value: foreground.hexDigits),
            URLQueryItem(name: "bg", value: background.hexDigits),
            URLQueryItem(name: "photo", value: String(catalogIndex)),
        ]
        components.queryItems = items
        return components.url!
    }

    /// The web's Markdown export, character for character (PM §14).
    var markdown: String {
        "# Color Shift\n\n![\(photo.alt)](\(photo.webImageURL.absoluteString))\n\n"
            + "Photo by [\(photo.photographer)](https://unsplash.com/@\(photo.handle)) on Unsplash.\n\n"
            + "- Foreground: `\(foreground.hex)`\n- Background: `\(background.hex)`\n"
            + "- WCAG contrast: **\(ColorMath.formatRatio(wcag)):1**\n"
    }

    var markdownFileName: String { "color-shift-\(foreground.hexDigits)-\(background.hexDigits).md" }

    // MARK: Persistence

    /// Saves preferences; called when the scene goes to the background (ios.md §5).
    func save() {
        defaults.set(hapticsEnabled, forKey: Self.hapticsKey)
    }
}
