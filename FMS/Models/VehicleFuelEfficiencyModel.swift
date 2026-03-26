import Foundation

/// Maps the `vehicle_fuel_efficiency` Supabase view.
public struct VehicleFuelEfficiency: Codable, Identifiable {
  public var id: String { vehicleId }
  public let vehicleId: String
  public let plateNumber: String
  public let totalTrips: Int
  public let kmPerLiter: Double
  public let baselineKmPerLiter: Double?

  enum CodingKeys: String, CodingKey {
    case vehicleId = "vehicle_id"
    case plateNumber = "plate_number"
    case totalTrips = "total_trips"
    case kmPerLiter = "km_per_liter"
    case baselineKmPerLiter = "baseline_km_per_liter"
  }

  public init(
    vehicleId: String,
    plateNumber: String,
    totalTrips: Int,
    kmPerLiter: Double,
    baselineKmPerLiter: Double?
  ) {
    self.vehicleId = vehicleId
    self.plateNumber = plateNumber
    self.totalTrips = totalTrips
    self.kmPerLiter = kmPerLiter
    self.baselineKmPerLiter = baselineKmPerLiter
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    vehicleId = try container.decode(String.self, forKey: .vehicleId)
    plateNumber = try container.decode(String.self, forKey: .plateNumber)
    totalTrips = try container.decodeIfPresent(Int.self, forKey: .totalTrips) ?? 0
    kmPerLiter = try container.decodeIfPresent(Double.self, forKey: .kmPerLiter) ?? 0
    baselineKmPerLiter = try container.decodeIfPresent(Double.self, forKey: .baselineKmPerLiter)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(vehicleId, forKey: .vehicleId)
    try container.encode(plateNumber, forKey: .plateNumber)
    try container.encode(totalTrips, forKey: .totalTrips)
    try container.encode(kmPerLiter, forKey: .kmPerLiter)
    try container.encodeIfPresent(baselineKmPerLiter, forKey: .baselineKmPerLiter)
  }

  /// Color tier based on efficiency value.
  public enum EfficiencyTier {
    case good, moderate, poor

    public init(kmPerLiter: Double) {
      if kmPerLiter >= 10 {
        self = .good
      } else if kmPerLiter >= 7 {
        self = .moderate
      } else {
        self = .poor
      }
    }
  }

  public var tier: EfficiencyTier { .init(kmPerLiter: kmPerLiter) }

  public var percentDifference: Double {
    guard let baselineKmPerLiter, baselineKmPerLiter > 0 else { return 0 }
    return ((kmPerLiter - baselineKmPerLiter) / baselineKmPerLiter) * 100
  }
}
