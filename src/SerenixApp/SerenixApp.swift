import SwiftUI

@main
struct SerenixApp: App {
    @StateObject private var connection = StrapConnection()

    var body: some Scene {
        WindowGroup {
            MainView(connection: connection)
        }
    }
}
