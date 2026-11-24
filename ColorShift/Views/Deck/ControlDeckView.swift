import SwiftUI

/// The control deck ("mixer drawer"). Sections arrive in T-030…T-035.
struct ControlDeckView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
                Text("Color controls")
                    .typeStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Text.deck.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.deckPadding)
        }
        .accessibilityIdentifier("controlDeck")
    }
}
