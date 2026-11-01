import SerenixCore
import SwiftUI

/// Settings, reached from the main screen: the way to the debug screen (spec 001) and the
/// version of this build.
struct SettingsView: View {
    @ObservedObject var connection: StrapConnection

    var body: some View {
        List {
            Section {
                NavigationLink("Debug") { DebugView(connection: connection) }
            }
            Section {
                LabeledContent("Version", value: BuildInfo.version)
            }
        }
        .navigationTitle("Settings")
    }
}
