/// Events that play haptic feedback (ios.md §10). The model emits them from its actions; one view
/// modifier plays them, gated by `AppModel.hapticsEnabled`.
nonisolated enum HapticEvent: Sendable, Equatable {
    case photoChanged
    case themeToggled
    case drawerToggled
    case swapped
    case jumpReached
    case jumpMissed
    case sliderReachedEnd
    case contrastRose      // crossed 4.5 or 7 upward while dragging a slider
    case contrastFell      // fell below 4.5 while dragging a slider
    case linkCopied
}

/// Changes on every emission, so the same event twice in a row still plays.
nonisolated struct HapticSignal: Sendable, Equatable {
    let event: HapticEvent
    let serial: Int
}
