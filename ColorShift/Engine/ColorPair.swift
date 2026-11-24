/// A foreground/background pair. The web stores fallbacks as `[bg, fg]`; this names them.
nonisolated struct ColorPair: Hashable, Sendable, Codable {
    var background: SRGB8
    var foreground: SRGB8
}
