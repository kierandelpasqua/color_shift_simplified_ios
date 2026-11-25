import ImageIO
import SwiftUI

/// The photo area (PM §9, §13; ios.md §6). One tap action and one swipe action, each of which closes the
/// open drawer instead of navigating. The image is downsampled to the panel's size, revealed with M2, and
/// the photo's derived pair is applied once it's ready.
struct PhotoPanelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    /// The image on screen and the photo it belongs to. It changes only once the next image is decoded, so
    /// the old photo stays up until the new one can be revealed over it.
    @State private var shown: (id: Photo.ID, image: CGImage)?

    /// A drag this far (pt) is a swipe (PM §13: 35px).
    static let swipeDistance: CGFloat = 35

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Button {
                    model.photoTapped()
                } label: {
                    image(size: proxy.size)
                }
                .buttonStyle(.plain)
                // Wins over the button once the finger moves 10pt, so a swipe never also counts as a tap
                // (the web's double advance, ios.md §14).
                .highPriorityGesture(DragGesture(minimumDistance: 10).onEnded(swiped))
                .accessibilityLabel(model.photo.alt)
                .accessibilityHint("Double-tap for next photo")
                .accessibilityValue(model.photo.id)
                .accessibilityIdentifier("photoPanel")
                // Swipes aren't discoverable with VoiceOver (ios.md §11).
                .accessibilityAction(named: "Next photo") { model.navigate(1) }
                .accessibilityAction(named: "Previous photo") { model.navigate(-1) }

                PhotoCredit(photo: model.photo)
                    .padding(Tokens.Spacing.creditInset)
            }
            .task(id: LoadKey(id: model.photo.id, size: proxy.size)) { await load(size: proxy.size) }
        }
        .task(id: model.photo.id) { await derive() }
    }

    private func image(size: CGSize) -> some View {
        ZStack {
            Tokens.Surface.photoPlaceholder.color
            if let shown {
                Image(decorative: shown.image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .id(shown.id)
                    .transition(AsymmetricTransition(insertion: PhotoReveal(reduceMotion: reduceMotion),
                                                     removal: .identity))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())   // `clipped()` doesn't limit hit testing; the overflow must not be tappable.
        .accessibilityIgnoresInvertColors()
    }

    private func swiped(_ value: DragGesture.Value) {
        let dx = value.translation.width
        if dx > Self.swipeDistance {
            model.photoSwiped(-1)
        } else if dx < -Self.swipeDistance {
            model.photoSwiped(1)
        } else if model.controlsOpen {
            model.controlsOpen = false   // Any touch on the photo closes the open drawer (PM §13).
        }
    }

    private struct LoadKey: Hashable { let id: Photo.ID; let size: CGSize }

    private func load(size: CGSize) async {
        let photo = model.photo
        guard size.width > 0, size.height > 0,
              let image = await PhotoImageCache.shared.image(for: photo, filling: size, scale: displayScale),
              !Task.isCancelled
        else { return }
        if shown?.id == photo.id {
            shown = (photo.id, image)   // Same photo at a new size: swap without replaying the reveal.
        } else {
            withAnimation(Motion.reveal(reduceMotion: reduceMotion)) { shown = (photo.id, image) }
        }
    }

    private func derive() async {
        #if DEBUG
        // UI tests that check exact colors start from the fallback pair (`-disablePhotoDerivation YES`).
        if UserDefaults.standard.bool(forKey: "disablePhotoDerivation") { return }
        #endif
        let photo = model.photo
        let result = await DerivedPairCache.shared.result(for: photo)
        guard !Task.isCancelled else { return }
        model.photoDidDerive(result?.pair, for: photo.id)
    }
}

/// M2: opacity 0→1, scale 1.04→1, blur 8→0 (PM §12). Under Reduce Motion, a fade only.
struct PhotoReveal: Transition {
    var reduceMotion: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        let animated = !phase.isIdentity && !reduceMotion
        content
            .opacity(phase.isIdentity ? 1 : Motion.revealStartOpacity)
            .scaleEffect(animated ? Motion.revealStartScale : 1)
            .blur(radius: animated ? Motion.revealStartBlur : 0)
    }
}

/// "Photo <Name>" on a dark chip, linking to the photographer on Unsplash (PM §9 PhotoCredit, ios.md §13).
/// It sits outside the photo's button, so tapping it never changes the photo.
struct PhotoCredit: View {
    let photo: Photo

    var body: some View {
        Link(destination: photo.photographerURL) {
            HStack(spacing: 4) {
                Text("Photo").foregroundStyle(Tokens.Text.creditLabel.color)
                Text(photo.photographer).foregroundStyle(Tokens.Text.creditName.color)
            }
            .typeStyle(Typography.credit)
            .fixedSize()   // Natural width: names never truncate (the chip grows with Dynamic Type).
            .padding(.vertical, 7.68)
            .padding(.horizontal, 10.4)
            .background(Tokens.Surface.credit.color, in: .rect(cornerRadius: Tokens.Radius.credit))
            .background(.ultraThinMaterial, in: .rect(cornerRadius: Tokens.Radius.credit))
            .shadow(color: Tokens.Effect.creditShadow.color, radius: 6, y: 2)
            .frame(minHeight: Tokens.Size.minHitTarget)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Photo by \(photo.photographer) on Unsplash")
        .accessibilityHint("Opens the photographer's page in Safari")
        .accessibilityIdentifier("photoCredit")
    }
}

/// Downsampled photo images, decoded off the main actor and kept for the current photo and its neighbors.
actor PhotoImageCache {
    static let shared = PhotoImageCache()

    private var images: [String: CGImage] = [:]
    private var order: [String] = []
    private let limit = 4

    /// The photo decoded at the pixel size that fills `size` (cover-fit), capped by the file itself.
    func image(for photo: Photo, filling size: CGSize, scale: CGFloat, in bundle: Bundle = .main) async -> CGImage? {
        let longSide = Self.longSidePixels(aspect: photo.aspect, filling: size, scale: scale)
        let key = "\(photo.id)@\(longSide)"
        if let image = images[key] { return image }
        guard let url = bundle.url(forResource: photo.id, withExtension: "jpg"),
              let image = await Self.decode(url, maxPixel: longSide) else { return nil }
        images[key] = image
        order.append(key)
        if order.count > limit { images[order.removeFirst()] = nil }
        return image
    }

    /// Long side, in pixels, of an image of `aspect` scaled to cover `size`, rounded up to 128 px buckets
    /// so small size changes reuse the cache.
    nonisolated static func longSidePixels(aspect: Double, filling size: CGSize, scale: CGFloat) -> Int {
        let width = max(size.width, size.height * aspect)
        let height = max(size.height, size.width / aspect)
        let pixels = Int((max(width, height) * scale).rounded(.up))
        return min(2400, (pixels + 127) / 128 * 128)
    }

    @concurrent private static func decode(_ url: URL, maxPixel: Int) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
