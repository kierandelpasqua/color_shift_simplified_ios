import SwiftUI

/// Jellyfish mark + "Color Shift" / "PHOTO → PAIR" (PM §9). On iOS it's also the button that opens the
/// About sheet (T-045; ios.md §4).
struct IdentityView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var showsAbout = false

    var body: some View {
        Button { showsAbout = true } label: { brand }
            .buttonStyle(.plain)
            .frame(minHeight: Tokens.Size.minHitTarget)
            .contentShape(Rectangle())
            .accessibilityLabel("About Color Shift")
            .accessibilityHint("Credits, licenses, privacy and the Haptics setting")
            .accessibilityIdentifier("aboutButton")
            .sheet(isPresented: $showsAbout) { AboutSheet() }
    }

    private var brand: some View {
        HStack(spacing: 9.92) {
            JellyfishMark()
                .frame(width: 29.6, height: 29.6)
            VStack(alignment: .leading, spacing: 1.92) {
                Text("Color Shift")
                    .typeStyle(Typography.brandTitle)
                    .foregroundStyle(Tokens.Text.deck.color)
                Text("Photo → pair")
                    .typeStyle(Typography.brandSubtitle)
                    .foregroundStyle((contrast == .increased ? Tokens.Text.mutedIncreased : Tokens.Text.subtle).color)
            }
        }
    }
}
