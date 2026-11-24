import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The Markdown export as a real `.md` file for the share sheet (ios.md I10): Save to Files, AirDrop, Mail.
nonisolated struct MarkdownFile: Transferable, Sendable {
    let fileName: String
    let contents: String

    static let contentType = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: contentType) { file in
            SentTransferredFile(try file.write(to: FileManager.default.temporaryDirectory), allowAccessingOriginalFile: true)
        }
    }

    /// Writes `contents` (UTF-8) as `<directory>/<fileName>`, replacing any earlier export.
    func write(to directory: URL) throws -> URL {
        let folder = directory.appending(path: "MarkdownExport", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName)
        try Data(contents.utf8).write(to: url, options: .atomic)
        return url
    }
}
