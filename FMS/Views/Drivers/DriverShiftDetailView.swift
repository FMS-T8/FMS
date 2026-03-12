import SwiftUI

// MARK: - DriverShiftDetailView

/// Detail screen for a single shift, navigated to via `NavigationLink`
/// from `DriverShiftCardView`.
///
/// Shows driver name, assigned vehicle, shift timeline
/// (Shift Start → Break → Resume → Shift End from BreakLog),
/// and a `ProgressView` for shift progress.
struct DriverShiftDetailView: View {

    @State private var vm: ShiftViewModel

    init(shift: ShiftDisplayItem) {
        _vm = State(initialValue: ShiftViewModel(shift: shift))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                driverInfoCard
                shiftProgressCard
                timelineCard
                breakLogsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(FMSTheme.backgroundPrimary)
        .navigationTitle("Shift Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Driver Info

    private var driverInfoCard: some View {
        DetailCard {
            HStack(spacing: 14) {
                AvatarCircle(
                    initials: String(vm.driverName.split(separator: " ").prefix(2)
                        .compactMap { $0.first.map(String.init) }.joined()),
                    color: FMSTheme.amber,
                    size: 52
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.driverName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                    if let vName = vm.vehicleDisplayName {
                        HStack(spacing: 4) {
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(FMSTheme.textTertiary)
                            Text(vName)
                                .font(.system(size: 13))
                                .foregroundStyle(FMSTheme.textSecondary)
                        }
                    }
                    if let plate = vm.plateNumber {
                        Text("Plate: \(plate)")
                            .font(.system(size: 12))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Progress

    private var shiftProgressCard: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.amber)
                    Text("Shift Progress")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                }

                HStack {
                    Text("Progress")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textSecondary)
                    Spacer()
                    Text(vm.progressLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FMSTheme.textPrimary)
                }

                ProgressView(value: vm.progress)
                    .tint(FMSTheme.amber)
            }
        }
    }

    // MARK: - Timeline

    private var timelineCard: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "timeline.selection")
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.amber)
                    Text("Shift Timeline")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                }

                ForEach(vm.timelineEntries) { entry in
                    HStack(spacing: 12) {
                        // Time
                        Text(entry.formattedTime)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(FMSTheme.textPrimary)
                            .frame(width: 50, alignment: .leading)

                        // Dot + line
                        Circle()
                            .fill(timelineDotColor(entry.type))
                            .frame(width: 10, height: 10)

                        // Label
                        Text(entry.label)
                            .font(.system(size: 14))
                            .foregroundStyle(FMSTheme.textSecondary)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Break Logs

    private var breakLogsCard: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.amber)
                    Text("Breaks")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                }

                if vm.breakLogs.isEmpty {
                    Text("No breaks recorded")
                        .font(.system(size: 14))
                        .foregroundStyle(FMSTheme.textTertiary)
                } else {
                    ForEach(vm.breakLogs) { brk in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Break")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(FMSTheme.textPrimary)
                                if let st = brk.startTime {
                                    let f = DateFormatter()
                                    let _ = f.dateFormat = "hh:mm a"
                                    Text(f.string(from: st))
                                        .font(.system(size: 12))
                                        .foregroundStyle(FMSTheme.textSecondary)
                                }
                            }
                            Spacer()
                            if let dur = brk.durationMinutes {
                                Text("\(dur) minutes")
                                    .font(.system(size: 13))
                                    .foregroundStyle(FMSTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func timelineDotColor(_ type: ShiftTimelineEntry.EntryType) -> Color {
        switch type {
        case .shiftStart: return FMSTheme.alertGreen
        case .breakStart: return FMSTheme.amber
        case .resume:     return FMSTheme.alertGreen
        case .shiftEnd:   return FMSTheme.alertRed
        }
    }
}

// MARK: - Detail Card Container

private struct DetailCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
