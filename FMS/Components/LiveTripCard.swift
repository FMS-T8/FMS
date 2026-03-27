import SwiftUI

public struct LiveTripCard: View {
    public let plateNumber: String
    public let origin: String
    public let destination: String
    public let completionPercentage: Int
    
    // Theme colors matching the new aesthetics
    private let cardBackground = FMSTheme.cardBackground
    private let pillBackground = FMSTheme.pillBackground
    private let textPrimary = FMSTheme.textPrimary
    private let textSecondary = FMSTheme.textSecondary
    private let borderLight = FMSTheme.borderLight
    private let symbolColor = FMSTheme.symbolColor
    
    public init(plateNumber: String, origin: String, destination: String, completionPercentage: Int) {
        self.plateNumber = plateNumber
        self.origin = origin
        self.destination = destination
        self.completionPercentage = completionPercentage
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                // Left Column: Route Details
                VStack(alignment: .leading, spacing: 12) {
                    // Plate Number Badge
                    Text(plateNumber)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(FMSTheme.obsidian)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(FMSTheme.amber)
                        .cornerRadius(6)
                    
                    // Route with City Truncation
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 8) {
                            addressView(title: "From", value: origin)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(FMSTheme.textTertiary)
                            addressView(title: "To", value: destination)
                        }
                    }
                }
                
                Spacer()
                
                // Right Column: Iconic Truck
                ZStack {
                    Circle()
                        .fill(FMSTheme.pillBackground)
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "box.truck.fill")
                        .font(.system(size: 24))
                        .foregroundColor(FMSTheme.amber)
                }
            }
            
            // Progress Bar Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Trip Progress")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FMSTheme.textSecondary)
                    Spacer()
                    Text("\(completionPercentage)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FMSTheme.amber)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(FMSTheme.borderLight)
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(FMSTheme.amber)
                            .frame(width: geo.size.width * CGFloat(Double(completionPercentage) / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(FMSTheme.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
        .shadow(color: FMSTheme.shadowSmall, radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    private func addressView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(FMSTheme.textTertiary)
                .tracking(0.5)
            
            Text(cityOnly(value))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func cityOnly(_ fullName: String) -> String {
        let parts = fullName.components(separatedBy: ",")
        guard let first = parts.first else { return fullName }
        return first.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Previews
#Preview {
    ZStack {
        Color(red: 250/255, green: 250/255, blue: 252/255).ignoresSafeArea()
        
        VStack(spacing: 16) {
            LiveTripCard(
                plateNumber: "MH02H0942",
                origin: "MYS",
                destination: "BLR",
                completionPercentage: 48
            )
            
            LiveTripCard(
                plateNumber: "KA 09 MA 1234",
                origin: "DEL",
                destination: "MUM",
                completionPercentage: 12
            )
        }
        .padding(16)
    }
}
