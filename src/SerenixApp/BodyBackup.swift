import SerenixCore
import SwiftUI
import UniformTypeIdentifiers

/// All Body data as the JSON backup file the share sheet hands on (spec 015, Backup and
/// import). It's encoded only when shared.
struct BodyBackup: Transferable {
    let data: BodyData

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { backup in
            try BodyDataFile.encode(backup.data)
        }
        .suggestedFileName("Serenix Body data.json")
    }
}
