import SwiftUI

/// The control deck ("mixer drawer") in the web's ≤ 560px single-column order (PM §9, §11; ios.md §8):
/// topline (identity + export), theme chips, color readout, FG mix, BG mix, contrast.
struct ControlDeckView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12.8) {
                    HStack(alignment: .center) {
                        IdentityView()
                        Spacer(minLength: 12.8)
                        DeckSectionPlaceholder(title: "Export", id: "deck.export")
                    }
                    DeckSectionPlaceholder(title: "Themes", id: "deck.themes")
                }
                .padding(.bottom, 18.4)

                VStack(alignment: .leading, spacing: 24) {
                    DeckSectionPlaceholder(title: "Colors", id: "deck.readout")
                    DeckSectionPlaceholder(title: "FG mix", id: "deck.fgMix")
                    DeckSectionPlaceholder(title: "BG mix", id: "deck.bgMix")
                    DeckSectionPlaceholder(title: "Contrast", id: "deck.contrast")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.deckPadding)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("controlDeck")
    }
}

/// Stand-in for a deck section until its task lands (T-031…T-035).
private struct DeckSectionPlaceholder: View {
    let title: String
    let id: String

    var body: some View {
        Text(title)
            .typeStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Text.muted.color)
            .accessibilityIdentifier(id)
    }
}
