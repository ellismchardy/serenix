import SerenixCore
import SwiftUI

/// Onboarding (spec 014): the first-launch conversation. Serenix's lines on the left, the user's
/// answers on the right, and the open question's field and chips pinned at the bottom. It draws
/// whatever `Onboarding` returns and saves each answer to the Profile as it's given.
struct OnboardingScreen: View {
    @ObservedObject var connection: StrapConnection
    @ObservedObject var profile: ProfileStore
    @State private var conversation = Onboarding(
        currentYear: Calendar.current.component(.year, from: Date())
    )
    @State private var text = ""
    @FocusState private var fieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(conversation.bubbles.enumerated()), id: \.offset) {
                            index,
                            bubble in
                            BubbleView(bubble: bubble).id(index)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: conversation.bubbles.count) { _, count in
                    withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
            controls
                .padding(16)
                .background(Theme.background)
        }
        .background(Theme.background)
        // Find my Strap or Try again: connect, then run the first History Sync (spec 001).
        .onChange(of: conversation.isLookingForStrap) { _, looking in
            guard looking else { return }
            connection.syncNow()
            // The phase may already answer (Bluetooth off, or a link already up), with no change
            // to come.
            if let event = pairingEvent(for: connection.phase) { handle(event) }
        }
        .onChange(of: connection.phase) { _, phase in
            guard conversation.isLookingForStrap, let event = pairingEvent(for: phase) else {
                return
            }
            handle(event)
        }
    }

    /// How the connection's phase answers "Looking for your Strap…", if it does yet.
    private func pairingEvent(for phase: StrapPhase) -> Onboarding.Event? {
        switch phase {
        // A finished sync also means it connected, in case SwiftUI skipped the phases between.
        case .connected, .syncing, .synced:
            .strapConnected(model: connection.strapModel ?? connection.strapName ?? "your Strap")
        case .bluetoothUnavailable, .failed(_, .strapUnreachable), .failed(_, .cancelled):
            .strapNotFound
        // Subscribing fails when the Strap isn't paired (spec 001). `.other` also covers rarer
        // failures (not a Whoop 5.0, a missing characteristic, the History Record store), which
        // get the same pairing advice for now: `StrapConnection` doesn't tell them apart.
        case .failed(_, .other):
            .pairingRefused
        case .idle, .searching, .connecting:
            nil
        }
    }

    @ViewBuilder private var controls: some View {
        let offered = conversation.controls
        VStack(alignment: .leading, spacing: 10) {
            if let field = offered.field {
                HStack {
                    TextField(offered.placeholder ?? "", text: $text)
                        .textContentType(field == .name ? .givenName : nil)
                        .textInputAutocapitalization(field == .name ? .words : .never)
                        .keyboardType(field == .number ? .numberPad : .default)
                        .submitLabel(.send)
                        .focused($fieldIsFocused)
                        .onSubmit(send)
                        .padding(12)
                        .themeCard(RoundedRectangle(cornerRadius: 12))
                    Button("Send", action: send)
                        .buttonStyle(.borderedProminent)
                }
                .onAppear { fieldIsFocused = true }
            }
            if !offered.chips.isEmpty {
                HStack {
                    ForEach(offered.chips, id: \.label) { chip in
                        Button(chip.label) { handle(.chipTapped(chip)) }
                            .buttonStyle(.bordered)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func send() {
        handle(.submitted(text))
        text = ""
    }

    private func handle(_ event: Onboarding.Event) {
        if let change = conversation.handle(event) { profile.apply(change) }
        if conversation.isFinished { profile.finishOnboarding() }
    }
}

private struct BubbleView: View {
    let bubble: Onboarding.Bubble

    var body: some View {
        let fromUser = bubble.speaker == .user
        HStack {
            if fromUser { Spacer(minLength: 48) }
            Text(bubble.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(fromUser ? Color.white : Color.primary)
                .background(
                    fromUser ? Theme.accent : Theme.card,
                    in: RoundedRectangle(cornerRadius: 18)
                )
            if !fromUser { Spacer(minLength: 48) }
        }
    }
}
