import Foundation
import SwiftUI

// MARK: - Issue Category

public enum IssueCategory: String, Codable, CaseIterable, Identifiable {
    case engine = "Engine"
    case brakes = "Brakes"
    case tires = "Tires"
    case electrical = "Electrical"
    case body = "Body Damage"
    case other = "Other"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .engine: return "engine.combustion"
        case .brakes: return "exclamationmark.triangle"
        case .tires: return "circle.circle"
        case .electrical: return "bolt.fill"
        case .body: return "car.side.fill"
        case .other: return "wrench.fill"
        }
    }
}

// MARK: - Issue Severity

public enum IssueSeverity: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .low: return FMSTheme.alertGreen
        case .medium: return FMSTheme.alertAmber
        case .high: return FMSTheme.alertOrange
        case .critical: return FMSTheme.alertRed
        }
    }
}

// MARK: - Issue Report

public struct IssueReport: Codable, Identifiable {
    public var id: String
    public var driverId: String?
    public var vehicleId: String?
    public var tripId: String?
    public var category: IssueCategory
    public var description: String
    public var severity: IssueSeverity
    public var photoData: [Data]?
    public var status: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        driverId: String? = nil,
        vehicleId: String? = nil,
        tripId: String? = nil,
        category: IssueCategory = .engine,
        description: String = "",
        severity: IssueSeverity = .medium,
        photoData: [Data]? = nil,
        status: String? = "open",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.tripId = tripId
        self.category = category
        self.description = description
        self.severity = severity
        self.photoData = photoData
        self.status = status
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case category
        case description
        case severity
        case photoData = "photo_data"
        case status
        case createdAt = "created_at"
    }
}
