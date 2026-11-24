import SwiftUI

@main
struct ColorShiftApp: App {
    var body: some Scene {
        WindowGroup {
            // Placeholder canvas until the real views land (Phase 2).
            // #111214 is the web's page background (PM §10); moves to Tokens in T-003.
            Color(red: 0x11 / 255, green: 0x12 / 255, blue: 0x14 / 255)
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
        }
    }
}
