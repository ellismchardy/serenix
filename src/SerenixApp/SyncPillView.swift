import SerenixCore
import SwiftUI

/// The sync pill that slides down over the top of the Today screen (spec 002, Sync pill):
/// a spinner, a purple outline and 001's progress while syncing, green ✓ when a sync finishes, amber ⚠
/// when it's paused and red ✕ when it failed. The Today view decides which; the screen decides
/// how long it stays up.
struct SyncPillView: View {
    let pill: SyncPill
    /// 001's progress and time left, shown under a syncing pill.
    let progress: Double?
    let timeLeft: TimeInterval?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                icon
                Text(pill.text).font(.subheadline.weight(.semibold))
            }
            // Nothing until the sync reports progress: "Syncing" with its spinner says enough.
            if pill.showsProgress, let progress {
                SyncProgressView(progress: progress, timeLeft: timeLeft)
            }
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

/// A running sync's progress bar and time left (spec 001, Sync progress).
private struct SyncProgressView: View {
    let progress: Double
    let timeLeft: TimeInterval?

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: progress).frame(width: 180)
            if let timeLeft {
                Text(HistorySync.timeLeftText(timeLeft))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
