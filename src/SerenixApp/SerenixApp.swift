import SerenixCore
import SwiftUI

@main
struct SerenixApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Serenix \(BuildInfo.version)")
        }
    }
}
