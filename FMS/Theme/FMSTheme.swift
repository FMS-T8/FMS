import SwiftUI

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

public struct FMSTheme {
    // Primary colors
    public static let amber = Color(red: 246/255, green: 201/255, blue: 68/255)
    public static let amberDark = Color(red: 200/255, green: 160/255, blue: 50/255)
    public static let obsidian = Color(red: 18/255, green: 18/255, blue: 18/255)
    
    // Background colors
    public static let backgroundPrimary = Color(
        light: Color(red: 250/255, green: 250/255, blue: 252/255),
        dark: Color(red: 18/255, green: 18/255, blue: 20/255)
    )
    public static let cardBackground = Color(
        light: .white,
        dark: Color(red: 28/255, green: 28/255, blue: 30/255)
    )
    
    // Component Backgrounds
    public static let pillBackground = Color(
        light: Color(red: 242/255, green: 242/255, blue: 247/255),
        dark: Color(red: 44/255, green: 44/255, blue: 46/255)
    )
    
    public static let symbolBackground = Color(
        light: Color.black.opacity(0.04),
        dark: Color.white.opacity(0.1)
    )
    
    // Text colors
    public static let textPrimary = Color(
        light: Color(red: 30/255, green: 30/255, blue: 35/255),
        dark: Color(red: 240/255, green: 240/255, blue: 245/255)
    )
    public static let textSecondary = Color(
        light: Color(red: 110/255, green: 110/255, blue: 120/255),
        dark: Color(red: 150/255, green: 150/255, blue: 160/255)
    )
    public static let textTertiary = Color(
        light: Color(red: 160/255, green: 160/255, blue: 165/255),
        dark: Color(red: 110/255, green: 110/255, blue: 115/255)
    )
    
    // Icon & Symbol colors
    public static let symbolColor = Color(
        light: Color(red: 80/255, green: 80/255, blue: 90/255),
        dark: Color(red: 170/255, green: 170/255, blue: 180/255)
    )
    
    // Alert colors
    public static let alertAmber = Color(red: 246/255, green: 201/255, blue: 68/255)
    public static let alertYellow = Color(red: 255/255, green: 220/255, blue: 100/255)
    public static let alertRed = Color(red: 230/255, green: 80/255, blue: 80/255)
    public static let alertGreen = Color(red: 50/255, green: 190/255, blue: 100/255)
    public static let alertOrange = Color(red: 240/255, green: 150/255, blue: 50/255)
    
    // Border
    public static let borderLight = Color(
        light: Color(red: 235/255, green: 235/255, blue: 240/255),
        dark: Color(red: 60/255, green: 60/255, blue: 65/255)
    )
    
    // Tab bar
    public static let tabInactive = Color(
        light: Color(red: 180/255, green: 180/255, blue: 185/255),
        dark: Color(red: 110/255, green: 110/255, blue: 115/255)
    )
    
    // Shadows
    public static let shadowSmall = Color(
        light: Color.black.opacity(0.05),
        dark: Color.black.opacity(0.3)
    )
    
    public static let shadowMedium = Color(
        light: Color.black.opacity(0.1),
        dark: Color.black.opacity(0.4)
    )
    
    public static let shadowLarge = Color(
        light: Color.black.opacity(0.12),
        dark: Color.black.opacity(0.4)
    )
    
    public static func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active":
            return alertGreen
        case "maintenance":
            return alertAmber
        case "inactive":
            return textTertiary
        default:
            return textTertiary
        }
    }
}
