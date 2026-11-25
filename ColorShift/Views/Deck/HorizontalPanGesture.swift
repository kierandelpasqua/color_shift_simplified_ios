import SwiftUI
import UIKit

/// A pan that only begins when the movement is mostly horizontal, so vertical swipes that start on a
/// slider still scroll the deck. (A SwiftUI `DragGesture` claims every touch inside a `ScrollView`.)
struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    /// Called with the touch's x in the view's local space, on begin and every move.
    let onChange: (CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChange(context.converter.localLocation.x)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }
    }
}

/// A tap that reports its x and, unlike SwiftUI's `onTapGesture`, fails once the finger moves (UIKit's
/// allowable movement, about 10pt). Otherwise a vertical swipe that nothing else claims, such as one
/// starting on a slider at the deck's top edge, would land as a tap and move the slider (T-046, Duo).
struct TapLocationGesture: UIGestureRecognizerRepresentable {
    /// Called with the tap's x in the view's local space.
    let onTap: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer { UITapGestureRecognizer() }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        if recognizer.state == .ended { onTap(context.converter.localLocation.x) }
    }
}
