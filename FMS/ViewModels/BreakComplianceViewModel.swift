import Foundation
import Observation
import Supabase

@MainActor
@Observable
public final class BreakComplianceViewModel {

  public struct BreakComplianceRule: Equatable {
    public var gentleHours: Double
    public var warningHours: Double
    public var criticalHours: Double
    public var minimumBreakMinutes: Int

    public init(
      gentleHours: Double = 2,
      warningHours: Double = 3.5,
      criticalHours: Double = 4.5,
      minimumBreakMinutes: Int = 15
    ) {
      self.gentleHours = gentleHours
      self.warningHours = warningHours
      self.criticalHours = criticalHours
      self.minimumBreakMinutes = minimumBreakMinutes
    }
  }

  public enum ComplianceStatus: String {
    case compliant
    case dueSoon
    case overdue
    case offDuty
  }

  public struct BreakComplianceDriver: Identifiable {
    public let id: String
    public let name: String
    public let employeeId: String
    public let vehicleLabel: String
    public let availabilityStatus: DriverAvailabilityStatus
    public let shiftStart: Date?
    public let shiftEnd: Date?
    public let requiredBreaks: Int
    public let compliantBreaks: Int
    public let missedBreaks: Int
    public let complianceScore: Double
    public let lastCompliantBreak: Date?
    public let dueInMinutes: Int?
    public let minutesSinceLastBreak: Int?
    public let status: ComplianceStatus
    public let isOnBreak: Bool
  }

  public var records: [BreakComplianceDriver] = []
  public var isLoading: Bool = false
  public var errorMessage: String? = nil
  public var lastUpdated: Date? = nil

  private let dataSource: DriversDataSource
  private var cachedDrivers: [DriverDisplayItem] = []
  private var cachedLogsByDriver: [String: [BreakLog]] = [:]

  public init(dataSource: DriversDataSource) {
    self.dataSource = dataSource
  }

  public convenience init() {
    self.init(dataSource: SupabaseDriversDataSource())
  }

  public func refresh() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let drivers = try await dataSource.fetchDrivers()
      let logsByDriver = try await fetchBreakLogs(for: drivers)
      cachedDrivers = drivers
      cachedLogsByDriver = logsByDriver

      let now = Date()
      let built = drivers.map { driver -> BreakComplianceDriver in
        let logs = logsByDriver[driver.id] ?? []
        return buildRecord(driver: driver, breakLogs: logs, now: now)
      }

      records = built.sorted(by: sortRecords)
      lastUpdated = now
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public var activeDriversCount: Int {
    records.filter { $0.status != .offDuty }.count
  }

  public var compliantDriversCount: Int {
    records.filter { $0.status == .compliant }.count
  }

  public var dueSoonDriversCount: Int {
    records.filter { $0.status == .dueSoon }.count
  }

  public var overdueDriversCount: Int {
    records.filter { $0.status == .overdue }.count
  }

  public var onBreakDriversCount: Int {
    records.filter { $0.isOnBreak && $0.status != .offDuty }.count
  }

  public var rule: BreakComplianceRule = BreakComplianceRule()

  public func recomputeFromCache() {
    guard !cachedDrivers.isEmpty else { return }
    let now = Date()
    let built = cachedDrivers.map { driver -> BreakComplianceDriver in
      let logs = cachedLogsByDriver[driver.id] ?? []
      return buildRecord(driver: driver, breakLogs: logs, now: now)
    }
    records = built.sorted(by: sortRecords)
    lastUpdated = now
  }

  // MARK: - Data Fetching

  private func fetchBreakLogs(for drivers: [DriverDisplayItem]) async throws
    -> [String: [BreakLog]]
  {
    let activeDrivers = drivers.filter { $0.shiftStart != nil }
    guard !activeDrivers.isEmpty else { return [:] }

    let driverIds = activeDrivers.map(\.id)
    let minShiftStart = activeDrivers.compactMap(\.shiftStart).min() ?? Date()
    let rangeEnd = Date()

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let response = try await SupabaseService.shared.client
      .from("break_logs")
      .select()
      .in("driver_id", values: driverIds)
      .gte("start_time", value: formatter.string(from: minShiftStart))
      .lte("start_time", value: formatter.string(from: rangeEnd))
      .order("start_time", ascending: true)
      .execute()

    let logs = try JSONDecoder.supabase().decode([BreakLog].self, from: response.data)
    return Dictionary(grouping: logs, by: { $0.driverId ?? "" })
  }

  // MARK: - Record Builder

  private func buildRecord(
    driver: DriverDisplayItem,
    breakLogs: [BreakLog],
    now: Date
  ) -> BreakComplianceDriver {
    let shiftStart = driver.shiftStart
    let shiftEnd = driver.shiftEnd

    if driver.availabilityStatus == .offDuty || shiftStart == nil {
      return BreakComplianceDriver(
        id: driver.id,
        name: driver.name,
        employeeId: driver.employeeID,
        vehicleLabel: driver.vehicleDisplayName ?? "Unassigned",
        availabilityStatus: driver.availabilityStatus,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        requiredBreaks: 0,
        compliantBreaks: 0,
        missedBreaks: 0,
        complianceScore: 1,
        lastCompliantBreak: nil,
        dueInMinutes: nil,
        minutesSinceLastBreak: nil,
        status: .offDuty,
        isOnBreak: false
      )
    }

    let currentRule = rule
    let effectiveShiftEnd = shiftEnd ?? now
    let elapsed = max(0, min(now, effectiveShiftEnd).timeIntervalSince(shiftStart ?? now))
    let elapsedHours = elapsed / 3600
    let requiredBreaks = max(0, Int(elapsedHours / currentRule.warningHours))

    let filteredLogs = breakLogs.filter { log in
      guard let start = log.startTime else { return false }
      if let s = shiftStart, start < s { return false }
      if let e = shiftEnd, start > e { return false }
      return true
    }

    let compliantLogs = filteredLogs.filter {
      guard let minutes = breakDurationMinutes(for: $0, now: now) else { return false }
      return minutes >= currentRule.minimumBreakMinutes
    }

    let compliantBreaks = compliantLogs.count
    let missedBreaks = max(0, requiredBreaks - compliantBreaks)
    let complianceScore: Double = requiredBreaks == 0
      ? 1
      : min(1, Double(compliantBreaks) / Double(requiredBreaks))

    let lastCompliantBreak = compliantLogs.compactMap { log -> Date? in
      if let end = log.endTime { return end }
      if let start = log.startTime { return start }
      return nil
    }
    .sorted().last

    let anchor = lastCompliantBreak ?? shiftStart ?? now
    let minutesSinceLast = Int(max(0, now.timeIntervalSince(anchor) / 60))
    let dueInMinutes = Int((currentRule.warningHours * 60) - Double(minutesSinceLast))

    let status: ComplianceStatus = {
      if let end = shiftEnd, now > end { return .offDuty }
      if Double(minutesSinceLast) >= currentRule.criticalHours * 60 { return .overdue }
      if Double(minutesSinceLast) >= currentRule.warningHours * 60 { return .dueSoon }
      return .compliant
    }()

    let isOnBreak = filteredLogs.contains { $0.isOngoing }

    return BreakComplianceDriver(
      id: driver.id,
      name: driver.name,
      employeeId: driver.employeeID,
      vehicleLabel: driver.vehicleDisplayName ?? "Unassigned",
      availabilityStatus: driver.availabilityStatus,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      requiredBreaks: requiredBreaks,
      compliantBreaks: compliantBreaks,
      missedBreaks: missedBreaks,
      complianceScore: complianceScore,
      lastCompliantBreak: lastCompliantBreak,
      dueInMinutes: dueInMinutes,
      minutesSinceLastBreak: minutesSinceLast,
      status: status,
      isOnBreak: isOnBreak
    )
  }

  private func breakDurationMinutes(for log: BreakLog, now: Date) -> Int? {
    if let minutes = log.durationMinutes { return minutes }
    guard let start = log.startTime else { return nil }
    let end = log.endTime ?? now
    return Int(max(0, end.timeIntervalSince(start) / 60))
  }

  private func sortRecords(
    _ lhs: BreakComplianceDriver,
    _ rhs: BreakComplianceDriver
  ) -> Bool {
    let priority: (ComplianceStatus) -> Int = { status in
      switch status {
      case .overdue: return 0
      case .dueSoon: return 1
      case .compliant: return 2
      case .offDuty: return 3
      }
    }

    let p1 = priority(lhs.status)
    let p2 = priority(rhs.status)
    if p1 != p2 { return p1 < p2 }
    return lhs.name < rhs.name
  }
}
