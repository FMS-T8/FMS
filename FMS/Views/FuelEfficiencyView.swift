import SwiftUI

/// User Story 2: Vehicle Fuel Efficiency list with color indicators and gauges.
public struct FuelEfficiencyView: View {
    @State private var viewModel = FuelEfficiencyViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading efficiency data…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                errorState(error)
            } else if viewModel.vehicles.isEmpty {
                ContentUnavailableView(
                    "No Efficiency Data",
                    systemImage: "fuelpump.slash",
                    description: Text("Vehicle fuel efficiency data will appear here once trips are logged.")
                )
            } else {
                contentView
            }
        }
        .navigationTitle("Fuel Efficiency")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .background(FMSTheme.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { viewModel.sortBestFirst.toggle() }
                } label: {
                    Label(
                        viewModel.sortBestFirst ? "Worst First" : "Best First",
                        systemImage: viewModel.sortBestFirst ? "arrow.up" : "arrow.down"
                    )
                }
            }
        }
        .task { await viewModel.fetchEfficiency() }
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.sortedVehicles) { vehicle in
                    EfficiencyRow(vehicle: vehicle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(FMSTheme.alertRed)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.fetchEfficiency() } }
                .buttonStyle(.borderedProminent)
                .tint(FMSTheme.amber)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
