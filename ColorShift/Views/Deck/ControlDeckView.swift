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
                        ExportActions()
                    }
                    ThemeChips()
                }
                .padding(.bottom, 18.4)

                VStack(alignment: .leading, spacing: 24) {
                    ColorReadout()
                    SliderGroup(role: .foreground)
                    SliderGroup(role: .background)
                    ContrastBlock()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.deckPadding)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("controlDeck")
    }
}
