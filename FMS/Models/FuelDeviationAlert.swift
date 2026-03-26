import Foundation

public enum FuelDeviationAlertStatus: String, Codable, CaseIterable {
  case active
  case acknowledged
  case resolved
}

public struct FuelDeviationAlert: Identifiable, Codable {
  public let vehicleId: String
  public let vehicleLabel: String
  public let currentRate: Double
  public let baselineRate: Double
  public let deviationPercent: Double
  public let timestamp: Date
  public var status: FuelDeviationAlertStatus

  public var id: String { vehicleId }

  public init(
    vehicleId: String,
    vehicleLabel: String,
    currentRate: Double,
    baselineRate: Double,
    deviationPercent: Double,
    timestamp: Date,
    status: FuelDeviationAlertStatus = .active
  ) {
    self.vehicleId = vehicleId
    self.vehicleLabel = vehicleLabel
    self.currentRate = currentRate
    self.baselineRate = baselineRate
    self.deviationPercent = deviationPercent
    self.timestamp = timestamp
    self.status = status
  }
}
