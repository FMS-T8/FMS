import Foundation

/// Maps the `fleet_utilization` Supabase view.
public struct FleetUtilization: Decodable, Identifiable {
  public var id: String { vehicleId }
  public let vehicleId: String
  public let plateNumber: String
  public let utilizationPercent: Double
  public let availableHours: Double
  public let activeHours: Double

  enum CodingKeys: String, CodingKey {
    case vehicleId = "vehicle_id"
    case plateNumber = "plate_number"
    case utilizationPercent = "utilization_percent"
    case availableHours = "available_hours"
    case activeHours = "active_hours"
  }

  public init(
    vehicleId: String,
    plateNumber: String,
    utilizationPercent: Double,
    availableHours: Double,
    activeHours: Double
  ) {
    self.vehicleId = vehicleId
    self.plateNumber = plateNumber
    self.utilizationPercent = utilizationPercent
    self.availableHours = availableHours
    self.activeHours = activeHours
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    vehicleId = try container.decode(String.self, forKey: .vehicleId)
    plateNumber = try container.decode(String.self, forKey: .plateNumber)
    utilizationPercent =
      try container.decodeIfPresent(Double.self, forKey: .utilizationPercent) ?? 0
    availableHours = try container.decodeIfPresent(Double.self, forKey: .availableHours) ?? 0
    activeHours = try container.decodeIfPresent(Double.self, forKey: .activeHours) ?? 0
  }

  /// Color tier based on utilization percentage.
  public enum UtilizationTier {
    case high, medium, low

    public init(percent: Double) {
      if percent >= 70 {
        self = .high
      } else if percent >= 40 {
        self = .medium
      } else {
        self = .low
      }
    }
  }

  public var tier: UtilizationTier { .init(percent: utilizationPercent) }
}
