import SwiftUI

struct BreakLogView: View {
    @Bindable var vm: BreakLogViewModel
    let driverId: String
    let tripId: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    breakTypeSection
                    notesSection
                    submitButton

                    if !vm.breakLogs.isEmpty || vm.isOnBreak {
                        historySection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Start Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Break Type Grid

    private var breakTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Break Type")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(BreakType.allCases) { type in
                    let isSelected = vm.selectedBreakType == type

                    Button {
                        vm.selectedBreakType = type
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20, weight: .semibold))
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(isSelected ? FMSTheme.obsidian : FMSTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? FMSTheme.amber : FMSTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.clear : FMSTheme.borderLight, lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                Text("(optional)")
                    .font(.system(size: 13))
                    .foregroundStyle(FMSTheme.textTertiary)
            }

            TextField("E.g. rest stop at NH-48, highway dhaba...", text: $vm.notes, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(3...6)
                .padding(14)
                .background(FMSTheme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FMSTheme.borderLight, lineWidth: 1)
                )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            startBreak()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Start Break")
                    .font(.headline.weight(.bold))
            }
        }
        .buttonStyle(.fmsPrimary)
    }

    // MARK: - Break History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(FMSTheme.borderLight)
                .frame(height: 1)

            Text("Today's Breaks")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            if vm.isOnBreak, let start = vm.currentBreakStartTime {
                let ongoingLog = BreakLog(id: "ongoing", tripId: tripId, driverId: driverId, breakType: vm.selectedBreakType.rawValue, startTime: start, endTime: nil, durationMinutes: nil, lat: nil, lng: nil, endLat: nil, endLng: nil, notes: vm.notes.isEmpty ? nil : vm.notes)
                BreakHistoryRow(breakLog: ongoingLog)
            }

            ForEach(vm.breakLogs) { log in
                BreakHistoryRow(breakLog: log)
            }
        }
    }

    // MARK: - Logic

    private func startBreak() {
        vm.startBreak(driverId: driverId, tripId: tripId)
        bannerManager.show(type: .success, message: "Break started. Tap 'End Break' when you're done.")
        dismiss()
    }
}
