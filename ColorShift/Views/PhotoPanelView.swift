import SwiftUI

/// The photo area. One tap action: closes the open drawer, otherwise shows the next photo (PM §13).
/// T-022 adds the image, reveal, swipe and credit; until then it shows the placeholder color.
struct PhotoPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.photoTapped()
        } label: {
            Tokens.Surface.photoPlaceholder.color
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.photo.alt)
        .accessibilityHint("Double-tap for next photo")
        .accessibilityValue(model.photo.id)
        .accessibilityIdentifier("photoPanel")
    }
}
