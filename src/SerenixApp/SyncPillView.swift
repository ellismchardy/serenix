import SerenixCore
import SwiftUI

/// The sync pill that slides down over the top of the Today screen (spec 002, Sync pill):
/// "Syncing" with a spinner and a purple outline while syncing, green ✓ when a sync finishes,
/// amber ⚠ when it's paused and red ✕ when it failed. 001's progress shows in the profile menu,
/// not here. The Today view decides which; the screen decides
/// how long it stays up.
struct SyncPillView: View {
    let pill: SyncPill

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(pill.text).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(colour.opacity(0.6)))
        .shadow(radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch pill.kind {
        case .syncing: ProgressView()
        case .successful: Image(systemName: "checkmark.circle.fill").foregroundStyle(colour)
        case .paused: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(colour)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(colour)
        }
    }

    private var colour: Color {
        switch pill.kind {
        case .syncing: Theme.accent
        case .successful: .green
        case .paused: .orange
        case .failed: .red
        }
    }
}
