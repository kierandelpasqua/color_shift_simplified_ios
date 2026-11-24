import SwiftUI

/// Plays the model's haptic events. Only feedback types that play on iPhone are used
/// (`.increase`, `.decrease`, `.start`, `.stop` and `.levelChange` are silent on iOS; ios.md §10).
struct HapticsModifier: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: model.haptic) { _, signal in
            guard model.hapticsEnabled, let signal else { return nil }
            return Self.feedback(for: signal.event)
        }
    }

    static func feedback(for event: HapticEvent) -> SensoryFeedback {
        switch event {
        case .photoChanged, .themeToggled: .selection
        case .drawerToggled: .impact(weight: .light)
        case .swapped: .impact(weight: .medium)
        case .jumpReached, .linkCopied: .success
        case .jumpMissed: .warning
        case .sliderReachedEnd: .alignment
        case .contrastRose: .impact(flexibility: .rigid, intensity: 0.6)
        case .contrastFell: .impact(flexibility: .soft, intensity: 0.5)
        }
    }
}
