import SwiftUI

/// The "Aa" specimen: the foreground on the background (PM §9, §10).
/// The type size comes from the specimen's own size, not Dynamic Type (ios.md §8).
struct SpecimenView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            let size = Self.fontSize(for: proxy.size)
            Self.specimenText(size: size)
                .font(Typography.specimen(size: size))
                .offset(x: 0.01 * size)
                .foregroundStyle(model.foreground.color)
                .lineLimit(1)
                .fixedSize()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityHidden(true)
        }
        .background(model.background.color)
        .clipped()
        .animation(Motion.colorChange, value: model.foreground)
        .animation(Motion.colorChange, value: model.background)
        .contentShape(Rectangle())
        .onTapGesture { model.specimenTapped() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Color specimen")
        .accessibilityValue("\(model.foreground.hex) on \(model.background.hex), contrast \(ColorMath.formatRatio(model.wcag)) to 1")
    }

    /// "Aa" with the web's −0.1em letter-spacing between the letters. SwiftUI's `.tracking` also shrinks the
    /// frame after the last letter, which clips the "a", so only the "A" is tracked. The web's box is then
    /// 0.1em narrower than this one; with its −0.04em shift, the matching offset here is +0.01em.
    static func specimenText(size: CGFloat) -> Text {
        var text = AttributedString("Aa")
        text[text.startIndex..<text.index(afterCharacter: text.startIndex)].tracking = -0.1 * size
        return Text(text)
    }

    /// Web: `clamp(80px, min(30cqw, 64cqh), 512px) + 10pt`, where 10pt = 13.33px (PM §10, D14).
    static func fontSize(for size: CGSize) -> CGFloat {
        min(512, max(80, min(0.30 * size.width, 0.64 * size.height))) + 13.33
    }
}
