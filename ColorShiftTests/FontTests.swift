import Testing
import UIKit
@testable import ColorShift

struct FontTests {
    nonisolated static let postScriptNames = [
        "Manrope-Regular", "Manrope-Medium", "Manrope-SemiBold", "Manrope-Bold",
        "DMMono-Regular", "DMMono-Medium",
    ]

    @Test(arguments: postScriptNames)
    func bundledFontResolves(_ name: String) {
        #expect(UIFont(name: name, size: 12) != nil, "\(name) is not registered (UIAppFonts / bundle)")
    }

    @Test func everyTypeStyleUsesABundledFont() {
        for style in Typography.all {
            #expect(Typography.isRegistered(style.postScriptName), "\(style.postScriptName)")
        }
        #expect(Typography.isRegistered("Manrope-SemiBold"))   // specimen
    }

    @Test(arguments: ["Manrope-OFL.txt", "DMMono-OFL.txt"])
    func licenseIsBundled(_ file: String) {
        let url = Bundle.main.url(forResource: file, withExtension: nil)
        #expect(url != nil, "\(file) missing from the app bundle (needed for the About sheet, T-045)")
    }
}
