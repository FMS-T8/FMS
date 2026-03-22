//
//  DriversViewModel.swift
//  FMS
//

import Foundation
import Observation

// MARK: - Drivers Data Source Protocol

/// Protocol for providing driver roster data to the DriversViewModel.
/// Implement this protocol for real repository/service or mock data sources.
public protocol DriversDataSource {
  func fetchDrivers() async throws -> [DriverDisplayItem]
}

// MARK: - Mock Data Source

/// Mock implementation of DriversDataSource for development and previews.
public final class MockDriversDataSource: DriversDataSource {
  public init() {}

  public func fetchDrivers() async throws -> [DriverDisplayItem] {
    DriversViewModel.makeMockDrivers()
  }
}

// MARK: - DriversViewModel

/// Central `@Observable` ViewModel for the Drivers module.
///
/// Holds all list data and directory state.
/// All computation happens here — views only read and bind.
@Observable
public final class DriversViewModel {

  // MARK: - Directory State
  public var drivers: [DriverDisplayItem] = []
  public var searchText: String = ""
  public var selectedFilter: DriverAvailabilityStatus? = nil
  
  // MARK: - UI State
  public var isLoading: Bool = false
  public var errorMessage: String? = nil
  
  private let dataSource: DriversDataSource

  // MARK: - Computed: Directory

  /// Filtered driver list (search + status filter).
  public var filteredDrivers: [DriverDisplayItem] {
    drivers.filter { item in
      let matchesSearch: Bool = {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return item.name.lowercased().contains(q)
          || item.employeeID.lowercased().contains(q)
      }()
      let matchesFilter: Bool = {
        guard let f = selectedFilter else { return true }
        return item.availabilityStatus == f
      }()
      return matchesSearch && matchesFilter
    }
  }

  /// Count of drivers matching a given status (for filter chip badges).
  public func driverCount(for status: DriverAvailabilityStatus?) -> Int {
    guard let status else { return drivers.count }
    return drivers.filter { $0.availabilityStatus == status }.count
  }

  /// On-duty drivers (for summary card).
  public var onDutyCount: Int { driverCount(for: .available) + driverCount(for: .onTrip) }
  /// On-trip drivers.
  public var onTripCount: Int { driverCount(for: .onTrip) }
  /// Off-duty drivers.
  public var offDutyCount: Int { driverCount(for: .offDuty) }
  /// Total drivers.
  public var totalCount: Int { drivers.count }

  // MARK: - Init

  /// Initializer with data source dependency injection.
  /// 🚨 THE FIX: Swapped the default parameter to SupabaseDriversDataSource() to force LIVE data! 🚨
  public init(dataSource: DriversDataSource = SupabaseDriversDataSource()) {
    self.dataSource = dataSource
  }
  
  /// Fetches fresh data from the data source.
  public func fetchData() async {
    isLoading = true
    errorMessage = nil
    
    do {
      self.drivers = try await dataSource.fetchDrivers()
    } catch {
      self.errorMessage = error.localizedDescription
      print("🚨 CRITICAL DRIVERS DECODING ERROR: \(error)")
    }
    
    isLoading = false
  }
}

// MARK: - Mock Data (Maintained strictly for SwiftUI Previews)

extension DriversViewModel {

  public static func makeMockDrivers() -> [DriverDisplayItem] {
    let now = Date()
    return [
      DriverDisplayItem(
        id: "drv-8821", name: "Alex Thompson", employeeID: "#DRV-8821",
        phone: "+91 98765 43210",
        vehicleId: "v-001", vehicleManufacturer: "Freightliner", vehicleModel: "M2",
        plateNumber: "FLD-829",
        availabilityStatus: .available,
        shiftStart: now.addingTimeInterval(-3 * 3600),
        shiftEnd: now.addingTimeInterval(5 * 3600),
        activeTripId: nil
      ),
      DriverDisplayItem(
        id: "drv-9104", name: "Sarah Jenkins", employeeID: "#DRV-9104",
        phone: "+91 98765 43211",
        vehicleId: "v-002", vehicleManufacturer: "Volvo", vehicleModel: "VNL 860",
        plateNumber: "XYZ-9876",
        availabilityStatus: .onTrip,
        shiftStart: now.addingTimeInterval(-6.75 * 3600),
        shiftEnd: now.addingTimeInterval(1.25 * 3600),
        activeTripId: "trip-001"
      ),
      DriverDisplayItem(
        id: "drv-7229", name: "Marcus Rodriguez", employeeID: "#DRV-7229",
        phone: "+91 98765 43212",
        vehicleId: "v-003", vehicleManufacturer: "Kenworth", vehicleModel: "T680",
        plateNumber: "KLC-4421",
        availabilityStatus: .offDuty,
        shiftStart: nil, shiftEnd: nil,
        activeTripId: nil
      ),
      DriverDisplayItem(
        id: "drv-8829", name: "Marcus Thompson", employeeID: "#DRV-8829",
        phone: "+91 98765 43213",
        vehicleId: "v-004", vehicleManufacturer: "Volvo", vehicleModel: "FH16",
        plateNumber: "TN11N3067",
        availabilityStatus: .available,
        shiftStart: now.addingTimeInterval(-1.5 * 3600),
        shiftEnd: now.addingTimeInterval(6.5 * 3600),
        activeTripId: "trip-002"
      ),
    ]
  }

}
