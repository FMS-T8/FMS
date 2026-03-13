import SwiftUI

// WorkOrdersView is no longer a tab (removed per user request).
// Kept as a compile stub in case it is referenced elsewhere.
public struct WorkOrdersView: View {
    @Environment(\.colorScheme) private var colorScheme
    public init() {}
    public var body: some View {
        Text("Work Orders have moved to the Dashboard tab.")
            .foregroundColor(FMSTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding()
    }
}
