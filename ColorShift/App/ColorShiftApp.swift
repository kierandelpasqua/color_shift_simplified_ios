import SwiftUI

@main
struct ColorShiftApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .modifier(HapticsModifier())
                .environment(model)
                .preferredColorScheme(.dark)
                #if DEBUG
                .onAppear {
                    // Screenshots: `xcrun simctl launch <device> <bundle id> -openControlsOnLaunch YES`.
                    if UserDefaults.standard.bool(forKey: "openControlsOnLaunch") { model.controlsOpen = true }
                }
                #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.save() }
        }
    }
}
