import Foundation
import Testing
import UIKit
@testable import ColorShift

struct ExportTests {
    private func model() -> AppModel {
        let defaults = UserDefaults(suiteName: "ExportTests-\(UUID().uuidString)")!
        let m = AppModel(defaults: defaults, webBaseURL: URL(string: "https://colorshift.example/")!)
        m.foreground = SRGB8(hex: "#F2D27A")!
        m.background = SRGB8(hex: "#1F3A5F")!
        return m
    }

    @Test func markdownFileHasWebNameAndContents() throws {
        let m = model()
        let file = m.markdownFile
        #expect(file.fileName == "color-shift-F2D27A-1F3A5F.md")
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = try file.write(to: dir)
        #expect(url.lastPathComponent == "color-shift-F2D27A-1F3A5F.md")
        #expect(try String(contentsOf: url, encoding: .utf8) == m.markdown)
        #expect(m.markdown.hasSuffix("- WCAG contrast: **7.81:1**\n"))
        // Exporting again replaces the earlier file.
        _ = try file.write(to: dir)
    }

    @Test func markdownTypeIsAPlainTextMdFile() {
        #expect(MarkdownFile.contentType.preferredFilenameExtension == "md")
        #expect(MarkdownFile.contentType.conforms(to: .plainText))
    }

    @Test func copyLinkWritesShareURLAndSetsCopied() {
        let m = model()
        let pasteboard = UIPasteboard.withUniqueName()
        m.copyLink(to: pasteboard)
        #expect(pasteboard.url == m.shareURL)
        #expect(m.linkCopied)
        UIPasteboard.remove(withName: pasteboard.name)
    }
}
