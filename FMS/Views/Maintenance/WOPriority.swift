import SwiftUI

public enum WOPriority: String, CaseIterable, Codable, Sendable {
    case high
    case medium
    case low
    case normal

    // Human-readable label used in UI
    public var label: String {
        switch self {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        case .normal: return "Normal Priority"
        }
    }

    // Foreground tint color for dots/text
    public var tint: Color {
        switch self {
        case .high: return FMSTheme.alertRed
        case .medium: return Color.blue
        case .low: return Color.gray
        case .normal: return FMSTheme.alertGreen
        }
    }

    // Background chip color
    public var bg: Color {
        switch self {
        case .high: return FMSTheme.alertRed.opacity(0.12)
        case .medium: return Color.blue.opacity(0.10)
        case .low: return Color.gray.opacity(0.10)
        case .normal: return FMSTheme.alertGreen.opacity(0.12)
        }
    }
}

public extension WOPriority {
    // Initialize from common strings used around the app
    init(from string: String) {
        let lower = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
        case "high", "critical": self = .high
        case "medium": self = .medium
        case "low": self = .low
        case "normal": self = .normal
        default: self = .normal
        }
    }

    // Failable init that returns nil for unknown values
    init?(safe string: String) {
        let lower = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
        case "high", "critical": self = .high
        case "medium": self = .medium
        case "low": self = .low
        case "normal": self = .normal
        default: return nil
        }
    }
}
