import Foundation
import Testing
@testable import ColorShift

private func makeModel() -> AppModel {
    AppModel(defaults: UserDefaults(suiteName: "HapticsTests-\(UUID().uuidString)")!,
             webBaseURL: URL(string: "https://colorshift.example/")!)
}
private func c(_ hex: String) -> SRGB8 { SRGB8(hex: hex)! }

struct HapticsTests {
    @Test func actionsEmitTheirEvents() {
        let m = makeModel()
        #expect(m.haptic == nil)
        m.navigate(1);            #expect(m.haptic?.event == .photoChanged)
        m.toggleTheme(.urban);    #expect(m.haptic?.event == .themeToggled)
        m.controlsOpen = true;    #expect(m.haptic?.event == .drawerToggled)
        m.swap();                 #expect(m.haptic?.event == .swapped)
        m.copyLink(to: .withUniqueName()); #expect(m.haptic?.event == .linkCopied)
    }

    @Test func repeatedEventsStillChangeTheSignal() {
        let m = makeModel()
        m.navigate(1); let first = m.haptic
        m.navigate(1)
        #expect(m.haptic != first)
        #expect(m.haptic?.event == .photoChanged)
    }

    @Test func settingDrawerToSameValueIsSilent() {
        let m = makeModel()
        m.controlsOpen = false
        #expect(m.haptic == nil)
    }

    @Test func jumpReachedAndMissed() {
        let m = makeModel()
        m.foreground = c("#8899AA"); m.background = c("#1F3A5F")
        m.jump(to: 4.5);  #expect(m.haptic?.event == .jumpReached)
        m.foreground = c("#777777"); m.background = c("#777777")
        m.jump(to: 7);    #expect(m.haptic?.event == .jumpMissed)
    }

    @Test func sliderEndsAndContrastCrossings() {
        let m = makeModel()
        m.foreground = c("#808080"); m.background = c("#000000")   // 5.32:1
        m.setChannel(.foreground, .lightness, 100)
        #expect(m.haptic?.event == .sliderReachedEnd)

        m.foreground = c("#3A3A3A"); m.background = c("#000000")   // below AA
        m.setChannel(.foreground, .lightness, 45)                  // #737373 ≈ 4.4 → still below
        let quiet = m.haptic
        m.setChannel(.foreground, .lightness, 50)                  // #808080 = 5.32 → crosses AA
        #expect(m.haptic != quiet)
        #expect(m.haptic?.event == .contrastRose)
        m.setChannel(.foreground, .lightness, 40)                  // back below AA
        #expect(m.haptic?.event == .contrastFell)
    }

    @Test func onlyIPhonePlayableFeedbackIsUsed() {
        let all: [HapticEvent] = [.photoChanged, .themeToggled, .drawerToggled, .swapped, .jumpReached,
                                  .jumpMissed, .sliderReachedEnd, .contrastRose, .contrastFell, .linkCopied]
        for event in all {
            let feedback = HapticsModifier.feedback(for: event)
            #expect(![.increase, .decrease, .start, .stop, .levelChange].contains(feedback), "\(event)")
        }
    }
}
