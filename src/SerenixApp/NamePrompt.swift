import SwiftUI

/// Asked once, on first launch, before the Today screen (spec 002, Profile): the name to greet
/// the user by, kept on this phone only. Continue saves it; Skip carries on without one.
struct NamePrompt: View {
    @ObservedObject var profile: ProfileStore
    @State private var name = ""
    @FocusState private var nameFieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("What should we call you?")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            TextField("Your name", text: $name)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($nameFieldIsFocused)
                .onSubmit { profile.answerNamePrompt(with: name) }
                .padding()
                .themeCard(RoundedRectangle(cornerRadius: 12))
            Text("Your name stays on this phone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Continue") { profile.answerNamePrompt(with: name) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Button("Skip") { profile.answerNamePrompt(with: nil) }
        }
        .padding(24)
        .onAppear { nameFieldIsFocused = true }
    }
}
