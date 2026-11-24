import SwiftUI

/// Jellyfish mark + "Color Shift" / "PHOTO → PAIR" (PM §9). Becomes the About sheet's entry point in T-045.
struct IdentityView: View {
    var body: some View {
        HStack(spacing: 9.92) {
            JellyfishMark()
                .frame(width: 29.6, height: 29.6)
            VStack(alignment: .leading, spacing: 1.92) {
                Text("Color Shift")
                    .typeStyle(Typography.brandTitle)
                    .foregroundStyle(Tokens.Text.deck.color)
                Text("Photo → pair")
                    .typeStyle(Typography.brandSubtitle)
                    .foregroundStyle(Tokens.Text.subtle.color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
