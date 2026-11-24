import SwiftUI
import UIKit

/// The iOS type scale (ios.md §8): the web's 8–12px styles raised to Apple's 11pt minimum and tied to
/// Dynamic Type text styles. Each base size equals its text style's default size, so the system-font
/// fallback (used until the bundled fonts are registered, H-04/T-004) scales identically.
struct TypeStyle: Sendable {
    enum Family: Sendable { case manrope, dmMono }

    let family: Family
    let weight: Font.Weight
    let size: CGFloat
    let textStyle: Font.TextStyle
    var uppercase = false

    /// PostScript name of the bundled face for this family and weight.
    var postScriptName: String {
        switch (family, weight) {
        case (.manrope, .bold): "Manrope-Bold"
        case (.manrope, .semibold): "Manrope-SemiBold"
        case (.manrope, .medium): "Manrope-Medium"
        case (.manrope, _): "Manrope-Regular"
        case (.dmMono, .medium): "DMMono-Medium"
        case (.dmMono, _): "DMMono-Regular"
        }
    }

    var font: Font {
        if Typography.isRegistered(postScriptName) {
            return .custom(postScriptName, size: size, relativeTo: textStyle)
        }
        return .system(textStyle, design: family == .dmMono ? .monospaced : .default, weight: weight)
    }
}

enum Typography {
    // ios.md §8 table, in order.
    static let tickLabel = TypeStyle(family: .dmMono, weight: .regular, size: 11, textStyle: .caption2)
    static let segment = TypeStyle(family: .dmMono, weight: .medium, size: 11, textStyle: .caption2)
    static let brandSubtitle = TypeStyle(family: .dmMono, weight: .regular, size: 11, textStyle: .caption2, uppercase: true)
    static let fieldLabel = TypeStyle(family: .dmMono, weight: .regular, size: 11, textStyle: .caption2, uppercase: true)
    static let button = TypeStyle(family: .dmMono, weight: .medium, size: 12, textStyle: .caption)
    static let chip = TypeStyle(family: .dmMono, weight: .medium, size: 12, textStyle: .caption)
    static let toast = TypeStyle(family: .dmMono, weight: .medium, size: 12, textStyle: .caption)
    static let credit = TypeStyle(family: .dmMono, weight: .medium, size: 12, textStyle: .caption)
    static let sectionTitle = TypeStyle(family: .manrope, weight: .bold, size: 13, textStyle: .footnote, uppercase: true)
    static let hexValue = TypeStyle(family: .dmMono, weight: .medium, size: 15, textStyle: .subheadline)
    static let brandTitle = TypeStyle(family: .manrope, weight: .bold, size: 15, textStyle: .subheadline)
    static let contrastValue = TypeStyle(family: .dmMono, weight: .medium, size: 22, textStyle: .title2)

    static let all: [TypeStyle] = [
        tickLabel, segment, brandSubtitle, fieldLabel, button, chip, toast, credit,
        sectionTitle, hexValue, brandTitle, contrastValue,
    ]

    /// The "Aa" specimen: Manrope SemiBold at a size computed from the specimen's geometry (T-021).
    /// Fixed size, not Dynamic Type: its 80pt minimum already exceeds the largest AX5 style.
    static func specimen(size: CGFloat) -> Font {
        let name = "Manrope-SemiBold"
        return isRegistered(name) ? .custom(name, fixedSize: size) : .system(size: size, weight: .semibold)
    }

    static func isRegistered(_ postScriptName: String) -> Bool {
        UIFont(name: postScriptName, size: 12) != nil
    }
}

extension View {
    /// Applies a type style's font and case.
    func typeStyle(_ style: TypeStyle) -> some View {
        font(style.font).textCase(style.uppercase ? .uppercase : nil)
    }
}
