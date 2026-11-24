import SwiftUI

/// Copy link and Markdown, icon-only like the web at ≤ 560px (PM §9, §11).
struct ExportActions: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6.4) {
            Button {
                model.copyLink()
            } label: {
                ExportIcon { CopyIcon() }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.linkCopied ? "Copied" : "Copy link")
            .accessibilityIdentifier("copyLinkButton")

            ShareLink(item: model.markdownFile, preview: SharePreview(model.markdownFileName)) {
                ExportIcon { DownloadIcon() }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export Markdown")
            .accessibilityIdentifier("markdownButton")
        }
    }
}

private struct ExportIcon<Icon: Shape>: View {
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        icon()
            .stroke(style: StrokeStyle(lineWidth: Tokens.Size.buttonIconStroke, lineCap: .round, lineJoin: .round))
            .frame(width: Tokens.Size.buttonIcon, height: Tokens.Size.buttonIcon)
            .foregroundStyle(Tokens.Text.button.color)
            .padding(.vertical, 8)
            .padding(.horizontal, 9.92)
            .background(Tokens.Surface.button.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.button))
            .frame(minWidth: Tokens.Size.minHitTarget, minHeight: Tokens.Size.minHitTarget)
            .contentShape(Rectangle())
    }
}

/// "Link copied to clipboard", bottom center, while `linkCopied` (web `.toast`, PM §12 M6).
struct CopiedToast: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if model.linkCopied {
                Text("Link copied to clipboard")
                    .typeStyle(Typography.toast)
                    .foregroundStyle(Tokens.Text.toast.color)
                    .padding(.vertical, 11.52)
                    .padding(.horizontal, 14.4)
                    .background(Tokens.Surface.button.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.toast))
                    .transition(Motion.toastTransition(reduceMotion: reduceMotion))
                    .accessibilityIdentifier("copiedToast")
            }
        }
        .animation(Motion.toastAnimation, value: model.linkCopied)
        .padding(.bottom, Tokens.Spacing.toastBottom)
        .allowsHitTesting(false)
        .onChange(of: model.linkCopied) { _, copied in
            if copied { AccessibilityNotification.Announcement("Link copied to clipboard").post() }
        }
    }
}
