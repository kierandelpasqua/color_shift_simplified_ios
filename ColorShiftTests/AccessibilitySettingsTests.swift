import Testing
@testable import ColorShift

struct AccessibilitySettingsTests {
    @Test func boldTextStepsUpOneBundledWeight() {
        #expect(Typography.fieldLabel.emboldened.postScriptName == "DMMono-Medium")
        #expect(Typography.chip.emboldened.postScriptName == "DMMono-Medium")      // already the heaviest DM Mono
        #expect(Typography.sectionTitle.emboldened.postScriptName == "Manrope-Bold")
        #expect(TypeStyle(family: .manrope, weight: .medium, size: 12, textStyle: .caption).emboldened.postScriptName == "Manrope-Bold")
        // Every emboldened face is bundled.
        for style in Typography.all { #expect(Typography.isRegistered(style.emboldened.postScriptName)) }
    }

    @Test func increasedContrastBordersAreVisibleOnTheDeck() {
        // Non-text UI needs 3:1 (WCAG 1.4.11) against the glass deck (~#15171A).
        let line = Tokens.Line.increased
        let ratio = ColorMath.contrast(SRGB8(r: line.red, g: line.green, b: line.blue), SRGB8(hex: "#15171A")!)
        #expect(ratio >= 3, "\(ratio)")
    }
}
