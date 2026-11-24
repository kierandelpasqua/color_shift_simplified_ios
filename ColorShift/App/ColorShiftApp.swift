import SwiftUI

@main
struct ColorShiftApp: App {
    var body: some Scene {
        WindowGroup {
            // Placeholder canvas until the real views land (Phase 2).
            Tokens.Surface.canvas.color
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
        }
    }
}
