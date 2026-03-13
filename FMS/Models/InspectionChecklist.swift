import Foundation

// MARK: - Inspection Type

public enum InspectionType: String, Codable, CaseIterable {
    case preTrip = "Pre-trip"
    case postTrip = "Post-trip"
}

// MARK: - Checklist Item Category

public enum InspectionCategory: String, Codable, CaseIterable, Identifiable {
    case tires = "Tires"
    case brakes = "Brakes"
    case lights = "Lights"
    case fluidLevels = "Fluid Levels"
    case engine = "Engine"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .tires: return "circle.circle"
        case .brakes: return "exclamationmark.triangle"
        case .lights: return "lightbulb"
        case .fluidLevels: return "drop.triangle"
        case .engine: return "engine.combustion"
        }
    }

    var criticalMessage: String {
        switch self {
        case .tires: return "Tire wear or pressure anomaly detected."
        case .brakes: return "Brake pad wear detected below safety limits."
        case .lights: return "One or more lights not functioning."
        case .fluidLevels: return "Fluid level below minimum threshold."
        case .engine: return "Engine check warning active."
        }
    }
}

// MARK: - Single Checklist Item

public struct InspectionItem: Identifiable, Codable {
    public var id: String
    public var category: InspectionCategory
    public var passed: Bool
    public var notes: String
    public var photoData: Data?

    public init(category: InspectionCategory) {
        self.id = UUID().uuidString
        self.category = category
        self.passed = false
        self.notes = ""
        self.photoData = nil
    }

    var hasIssue: Bool {
        !passed && (!notes.isEmpty || photoData != nil)
    }
}

// MARK: - Full Checklist

public struct InspectionChecklist: Identifiable, Codable {
    public var id: String
    public var vehicleId: String
    public var driverId: String
    public var inspectionType: InspectionType
    public var items: [InspectionItem]
    public var overallNotes: String
    public var completedAt: Date?
    public var createdAt: Date

    public init(vehicleId: String, driverId: String, type: InspectionType) {
        self.id = UUID().uuidString
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.inspectionType = type
        self.items = InspectionCategory.allCases.map { InspectionItem(category: $0) }
        self.overallNotes = ""
        self.completedAt = nil
        self.createdAt = Date()
    }

    var completedCount: Int {
        items.filter { $0.passed }.count
    }

    var totalCount: Int {
        items.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var allPassed: Bool {
        items.allSatisfy { $0.passed }
    }

    var failedItems: [InspectionItem] {
        items.filter { !$0.passed }
    }
}
