import SwiftUI

/// A row that becomes a column at accessibility text sizes (ios.md §8: `AnyLayout` HStack → VStack).
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout(content)
    }
}

/// A stroked 24×24 icon at a size that scales with Dynamic Type.
struct ScaledIcon<Icon: Shape>: View {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = Tokens.Size.buttonIcon
    let icon: Icon

    var body: some View {
        icon
            .stroke(style: StrokeStyle(lineWidth: Tokens.Size.buttonIconStroke, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
