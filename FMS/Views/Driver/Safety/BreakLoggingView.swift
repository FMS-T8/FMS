import SwiftUI

struct BreakLoggingView: View {
    @Bindable var viewModel: BreakLogViewModel
    let drivingTimer: DrivingTimerManager
    let driverId: String
    let tripId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            if viewModel.isOnBreak {
                activeBreakCard
            } else {
                startBreakCard
            }

            if viewModel.showMinDurationWarning {
                minDurationWarning
            }

            if !viewModel.breakLogs.isEmpty {
                recentBreaksSection
            }
        }
        
        .task {
            await viewModel.fetchBreakHistory()
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FMSTheme.amber)

            Text("Break Log")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            Spacer()

            if !viewModel.isOnBreak && drivingTimer.isActive {
                Text("Driving: \(drivingTimer.formattedDrivingTime)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(FMSTheme.pillBackground)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Start Break Card

    private var startBreakCard: some View {
        VStack(spacing: 14) {
            Text("Select break type")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FMSTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BreakType.allCases) { breakType in
                        BreakTypeChip(
                            breakType: breakType,
                            isSelected: viewModel.selectedBreakType == breakType,
                            onTap: { viewModel.selectedBreakType = breakType }
                        )
                    }
                }
            }

            // Notes Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Notes")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Text("(optional)")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textTertiary)
                }

                TextField("E.g. rest stop, highway dhaba...", text: $viewModel.notes, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(2...4)
                    .padding(12)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(FMSTheme.borderLight, lineWidth: 1)
                    )
            }
            .padding(.top, 4)

            Button {
                viewModel.startBreak(driverId: driverId.isEmpty ? nil : driverId,
                                     tripId: tripId.isEmpty ? nil : tripId)
                drivingTimer.startBreak()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start Break")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .buttonStyle(.fmsPrimary)
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Active Break Card

    private var activeBreakCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: viewModel.selectedBreakType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)

                Text("\(viewModel.selectedBreakType.rawValue) Break")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Spacer()

                Text("Active")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMSTheme.alertGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(FMSTheme.alertGreen.opacity(0.12))
                    .cornerRadius(8)
            }

            Text(viewModel.formattedElapsed)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(FMSTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            Button {
                viewModel.endBreak()
                let _ = drivingTimer.endBreak()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("End Break")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .buttonStyle(.fmsPrimary)
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.alertGreen.opacity(0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Min Duration Warning

    private var minDurationWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(FMSTheme.alertOrange)

            Text("Break was under 5 minutes — may not count toward rest requirements")
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.alertOrange)
        }
        .padding(12)
        .background(FMSTheme.alertOrange.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Recent Breaks

    private var recentBreaksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Breaks")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.textSecondary)

            ForEach(viewModel.breakLogs.prefix(3)) { log in
                BreakLogRow(log: log)
            }
        }
    }
}

// MARK: - Break Type Chip

private struct BreakTypeChip: View {
    let breakType: BreakType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: breakType.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(breakType.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? FMSTheme.obsidian : FMSTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? FMSTheme.amber : FMSTheme.pillBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Break Log Row

private struct BreakLogRow: View {
    let log: BreakLog

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForType)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.amber)
                .frame(width: 28, height: 28)
                .background(FMSTheme.amber.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.breakType ?? "Break")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Text(formattedTime)
                    .font(.system(size: 12))
                    .foregroundStyle(FMSTheme.textSecondary)

                if let notes = log.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.textPrimary.opacity(0.8))
                        .padding(.top, 4)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("\(log.durationMinutes ?? 0) min")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FMSTheme.textSecondary)
        }
        .padding(12)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    private var iconForType: String {
        guard let type = log.breakType, let breakType = BreakType(rawValue: type) else {
            return "bed.double.fill"
        }
        return breakType.icon
    }

    private var formattedTime: String {
        guard let start = log.startTime else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let startStr = formatter.string(from: start)
        if let end = log.endTime {
            return "\(startStr) – \(formatter.string(from: end))"
        }
        return "\(startStr) – now"
    }
}
