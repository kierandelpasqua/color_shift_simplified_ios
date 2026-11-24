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

/// Swap: `m7 7-3 3 3 3` + `M4 10h13M17 17l3-3-3-3M20 14H7`
nonisolated struct SwapIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let o = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        var path = Path()
        path.addLines([p(7, 7), p(4, 10), p(7, 13)])
        path.addLines([p(4, 10), p(17, 10)])
        path.addLines([p(17, 17), p(20, 14), p(17, 11)])
        path.addLines([p(20, 14), p(7, 14)])
        return path
    }
}

/// Arrow: `M5 12h14m-5-5 5 5-5 5`
nonisolated struct ArrowIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let o = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        var path = Path()
        path.addLines([p(5, 12), p(19, 12)])
        path.addLines([p(14, 7), p(19, 12), p(14, 17)])
        return path
    }
}

/// The jellyfish brand mark (36×36, filled; web `JellyfishMark`, PM §9): three layers.
nonisolated struct JellyfishMark: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 36
            func path(_ points: [(CGFloat, CGFloat)]) -> Path {
                var p = Path()
                p.addLines(points.map { CGPoint(x: $0.0 * s, y: $0.1 * s) })
                p.closeSubpath()
                return p
            }
            // M18 3 7 10l-3 9 6 3 3-5 2 6-4 7 4 3 3-7 3 7 4-3-4-7 2-6 3 5 6-3-3-9Z
            let body = path([(18, 3), (7, 10), (4, 19), (10, 22), (13, 17), (15, 23), (11, 30), (15, 33), (18, 26),
                             (21, 33), (25, 30), (21, 23), (23, 17), (26, 22), (32, 19), (29, 10)])
            context.fill(body, with: .color(Swatch(rgb: 0xFFFFFF).color))
            // m7 10 11-7v14H4Zm11-7 11 7 3 9-14-2Z
            context.fill(path([(7, 10), (18, 3), (18, 17), (4, 17)]), with: .color(Swatch(rgb: 0xB9BAC0).color))
            context.fill(path([(18, 3), (29, 10), (32, 19), (18, 17)]), with: .color(Swatch(rgb: 0xB9BAC0).color))
            // m4 19 14-2-8 5Zm14-2 14 2-6 3Z
            context.fill(path([(4, 19), (18, 17), (10, 22)]), with: .color(Swatch(rgb: 0x777983).color))
            context.fill(path([(18, 17), (32, 19), (26, 22)]), with: .color(Swatch(rgb: 0x777983).color))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
