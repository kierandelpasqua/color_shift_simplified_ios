import UIKit

/// Presents the system color picker (the same `UIColorPickerViewController` SwiftUI's `ColorPicker` uses)
/// from our own full-size readout button, like the web's hidden `input[type=color]` (PM §9).
final class ColorPickerPresenter: NSObject, UIColorPickerViewControllerDelegate {
    static let shared = ColorPickerPresenter()

    private var onChange: ((SRGB8) -> Void)?

    func present(title: String, color: SRGB8, onChange: @escaping (SRGB8) -> Void) {
        guard let presenter = Self.topViewController() else { return }
        self.onChange = onChange
        let picker = UIColorPickerViewController()
        picker.title = title
        picker.supportsAlpha = false
        picker.selectedColor = color.uiColor
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        onChange?(SRGB8(color))
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        onChange = nil
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
