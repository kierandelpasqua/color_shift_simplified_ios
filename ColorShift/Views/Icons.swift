import SwiftUI

/// The web's 24×24 stroke icons (PM §9), drawn as paths so they match exactly.
/// (ios.md §13 plans custom SF Symbols later so they scale with Dynamic Type.)
nonisolated struct MixerIcon: Shape {
    /// `M4 7h4m4 0h8M8 5v4M4 17h8m4 0h4m-4-2v4M4 12h16`
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let o = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        var path = Path()
        for (a, b) in [((4, 7), (8, 7)), ((12, 7), (20, 7)), ((8, 5), (8, 9)),
                       ((4, 17), (12, 17)), ((16, 17), (20, 17)), ((16, 15), (16, 19)),
                       ((4, 12), (20, 12))] as [((CGFloat, CGFloat), (CGFloat, CGFloat))] {
            path.move(to: p(a.0, a.1))
            path.addLine(to: p(b.0, b.1))
        }
        return path
    }
}
