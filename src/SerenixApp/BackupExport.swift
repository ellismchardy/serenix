import SerenixCore
import SwiftUI
import UniformTypeIdentifiers

/// A Backup of Nights, Days and Body data as the JSON file the share sheet hands on (spec 020).
/// It's encoded only when shared.
struct BackupExport: Transferable {
    let backup: Backup

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            try BackupFile.encode(export.backup)
        }
        .suggestedFileName("Serenix Backup.json")
    }
}
