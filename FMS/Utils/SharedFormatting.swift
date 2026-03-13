import Foundation

enum SharedFormatting {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()
    
    static func formatDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        return dateFormatter.string(from: date)
    }
    
    static func humanize(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let parts = cleaned.split(separator: " ")
        if parts.isEmpty { return value }
        return parts.map { $0.capitalized }.joined(separator: " ")
    }
}
