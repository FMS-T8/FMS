import SwiftUI

public struct DriverDashboardView: View {
    @State private var viewModel = DriverDashboardViewModel()

    public init() {}

    public var body: some View {
        FMSTabShell {
            FMSTabItem(id: "home", title: "Home", icon: "house.fill") {
                DriverHomeTab(viewModel: viewModel)
            }

            FMSTabItem(id: "trips", title: "Trips", icon: "map.fill") {
                DriverTripsTab(viewModel: viewModel)
            }
        }
    }
}
