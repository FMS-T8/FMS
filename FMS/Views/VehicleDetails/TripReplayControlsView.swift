import SwiftUI

/// Floating playback controls panel for Trip Replay.
public struct TripReplayControlsView: View {
    @Bindable var vm: TripReplayViewModel
    let trip: Trip

    public init(vm: TripReplayViewModel, trip: Trip) {
        self.vm = vm
        self.trip = trip
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ── Header row ──────────────────────────────────────────────
            tripHeaderRow
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            Divider().overlay(FMSTheme.borderLight).padding(.horizontal, 16)

            // ── Speed pill ──────────────────────────────────────────────
            speedPillRow
                .padding(.horizontal, 16)
                .padding(.top, 10)

            // ── Scrubber ────────────────────────────────────────────────
            scrubberRow
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // ── Time labels ─────────────────────────────────────────────
            timeLabelsRow
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            // ── Playback controls ───────────────────────────────────────
            playbackControlsRow
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: -4)
    }

    // MARK: - Sub-sections

    private var tripHeaderRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
                    .lineLimit(1)
                Text(trip.displayRoute)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(FMSTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            // Stats pills
            HStack(spacing: 6) {
                if let dist = trip.distanceKm {
                    statPill(icon: "map.fill", text: String(format: "%.0f km", dist))
                }
                statPill(icon: "point.3.connected.trianglepath.dotted",
                         text: "\(vm.totalPoints) pts")
            }
        }
    }

    private var speedPillRow: some View {
        HStack(spacing: 8) {
            // Current speed badge
            HStack(spacing: 5) {
                Circle()
                    .fill(speedColor)
                    .frame(width: 8, height: 8)
                if let kph = vm.currentSpeedKph {
                    Text(String(format: "%.0f km/h", kph))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FMSTheme.textPrimary)
                } else {
                    Text("—")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FMSTheme.textTertiary)
                }
                Text("·")
                    .foregroundColor(FMSTheme.textTertiary)
                Text(vm.speedCategory.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(speedColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(speedColor.opacity(0.12))
            .clipShape(Capsule())

            Spacer()

            // Speed picker
            HStack(spacing: 4) {
                ForEach([1.0, 2.0, 5.0], id: \.self) { speed in
                    Button {
                        vm.setSpeed(speed)
                    } label: {
                        Text("\(Int(speed))×")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(vm.playbackSpeed == speed ? FMSTheme.obsidian : FMSTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(vm.playbackSpeed == speed ? FMSTheme.amber : FMSTheme.backgroundPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: vm.playbackSpeed)
                }
            }
        }
    }

    private var scrubberRow: some View {
        Slider(
            value: Binding(
                get: { Double(vm.currentIndex) },
                set: { vm.seek(to: Int($0)) }
            ),
            in: 0...Double(max(vm.totalPoints - 1, 1)),
            step: 1
        )
        .tint(FMSTheme.amber)
    }

    private var timeLabelsRow: some View {
        HStack {
            Text(vm.elapsedLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(FMSTheme.textSecondary)
            Spacer()
            Text(vm.totalLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(FMSTheme.textTertiary)
        }
    }

    private var playbackControlsRow: some View {
        HStack(spacing: 24) {
            // Rewind to start
            Button {
                vm.reset()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(FMSTheme.textSecondary)
            }
            .buttonStyle(.plain)

            // Play / Pause (primary)
            Button {
                vm.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(FMSTheme.amber)
                        .frame(width: 52, height: 52)
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(FMSTheme.obsidian)
                        .offset(x: vm.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: vm.isPlaying)

            // Skip to end
            Button {
                vm.seek(to: vm.totalPoints - 1)
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(FMSTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var speedColor: Color {
        switch vm.speedCategory {
        case .normal:   return FMSTheme.alertGreen
        case .fast:     return FMSTheme.alertAmber
        case .speeding: return FMSTheme.alertRed
        }
    }

    private func statPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(FMSTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(FMSTheme.backgroundPrimary)
        .clipShape(Capsule())
    }
}
