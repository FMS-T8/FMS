# FMS Data Models

Consolidated reference of all model files under FMS/Models.

## Model Index
- [BreakLog](#BreakLog)
- [Company](#Company)
- [Driver](#Driver)
- [DriverVehicleAssignment](#DriverVehicleAssignment)
- [FuelLog](#FuelLog)
- [Geofence](#Geofence)
- [Incident](#Incident)
- [MaintenancePartsUsed](#MaintenancePartsUsed)
- [MaintenanceWorkOrder](#MaintenanceWorkOrder)
- [Notification](#Notification)
- [PartsInventory](#PartsInventory)
- [TelemetryData](#TelemetryData)
- [Trip](#Trip)
- [TripGPSLog](#TripGPSLog)
- [TripStop](#TripStop)
- [User](#User)
- [Vehicle](#Vehicle)
- [VehicleDocument](#VehicleDocument)
- [VehicleEvent](#VehicleEvent)
- [VehicleInspection](#VehicleInspection)

## BreakLog

Source: FMS/Models/BreakLog.swift

```swift
import Foundation

public struct BreakLog: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var driverId: String?
    public var startTime: Date?
    public var endTime: Date?
    public var durationMinutes: Int?
    public var lat: Double?
    public var lng: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case driverId = "driver_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case lat
        case lng
    }
}

```

## Company

Source: FMS/Models/Company.swift

```swift
import Foundation

public struct Company: Codable, Identifiable {
    public var id: String
    public var name: String
    public var vehicleIDs: [String]
    public var driverIDs: [String]
    
    public init(id: String = UUID().uuidString, name: String, vehicleIDs: [String] = [], driverIDs: [String] = []) {
        self.id = id
        self.name = name
        self.vehicleIDs = vehicleIDs
        self.driverIDs = driverIDs
    }
}

```

## Driver

Source: FMS/Models/Driver.swift

```swift
import Foundation

public struct Driver: Codable, Identifiable {
    public var id: String
    public var companyID: String
    public var name: String
    public var employeeID: String
    
    public init(id: String = UUID().uuidString, companyID: String, name: String, employeeID: String) {
        self.id = id
        self.companyID = companyID
        self.name = name
        self.employeeID = employeeID
    }
}

```

## DriverVehicleAssignment

Source: FMS/Models/DriverVehicleAssignment.swift

```swift
import Foundation

public struct DriverVehicleAssignment: Codable, Identifiable {
    public var id: String
    public var driverId: String?
    public var vehicleId: String?
    public var shiftStart: Date?
    public var shiftEnd: Date?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case shiftStart = "shift_start"
        case shiftEnd = "shift_end"
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

```

## FuelLog

Source: FMS/Models/FuelLog.swift

```swift
import Foundation

public struct FuelLog: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var driverId: String?
    public var fuelStation: String?
    public var amountPaid: Double?
    public var fuelVolume: Double?
    public var receiptImageUrl: String?
    public var loggedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case driverId = "driver_id"
        case fuelStation = "fuel_station"
        case amountPaid = "amount_paid"
        case fuelVolume = "fuel_volume"
        case receiptImageUrl = "receipt_image_url"
        case loggedAt = "logged_at"
    }
}

```

## Geofence

Source: FMS/Models/Geofence.swift

```swift
import Foundation

public struct Geofence: Codable, Identifiable {
    public var id: String
    public var name: String?
    public var centerLat: Double?
    public var centerLng: Double?
    public var radiusMeters: Int?
    public var createdBy: String?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case centerLat = "center_lat"
        case centerLng = "center_lng"
        case radiusMeters = "radius_meters"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

```

## Incident

Source: FMS/Models/Incident.swift

```swift
import Foundation

public struct Incident: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var vehicleId: String?
    public var driverId: String?
    public var severity: String?
    public var lat: Double?
    public var lng: Double?
    public var speedBefore: Double?
    public var speedAfter: Double?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case severity
        case lat
        case lng
        case speedBefore = "speed_before"
        case speedAfter = "speed_after"
        case createdAt = "created_at"
    }
}

```

## MaintenancePartsUsed

Source: FMS/Models/MaintenancePartsUsed.swift

```swift
import Foundation

public struct MaintenancePartsUsed: Codable, Identifiable {
    public var id: String
    public var workOrderId: String?
    public var partId: String?
    public var quantity: Int?
    public var cost: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case workOrderId = "work_order_id"
        case partId = "part_id"
        case quantity
        case cost
    }
}

```

## MaintenanceWorkOrder

Source: FMS/Models/MaintenanceWorkOrder.swift

```swift
import Foundation

public struct MaintenanceWorkOrder: Codable, Identifiable {
    public var id: String
    public var vehicleId: String?
    public var createdBy: String?
    public var assignedTo: String?
    public var description: String?
    public var priority: String?
    public var status: String?
    public var estimatedCost: Double?
    public var createdAt: Date?
    public var completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case createdBy = "created_by"
        case assignedTo = "assigned_to"
        case description
        case priority
        case status
        case estimatedCost = "estimated_cost"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

```

## Notification

Source: FMS/Models/Notification.swift

```swift
import Foundation

public struct Notification: Codable, Identifiable {
    public var id: String
    public var recipientId: String?
    public var type: String?
    public var vehicleId: String?
    public var tripId: String?
    public var message: String?
    public var isRead: Bool?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case type
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

```

## PartsInventory

Source: FMS/Models/PartsInventory.swift

```swift
import Foundation

public struct PartsInventory: Codable, Identifiable {
    public var id: String
    public var name: String?
    public var stock: Int?
    public var threshold: Int?
    public var unitCost: Double?
    public var lastUpdated: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case stock
        case threshold
        case unitCost = "unit_cost"
        case lastUpdated = "last_updated"
    }
}

```

## TelemetryData

Source: FMS/Models/TelemetryData.swift

```swift
import Foundation

public struct TelemetryData: Codable, Identifiable {
    public var id: String
    public var tripID: String
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    public var speed: Double
    
    public init(id: String = UUID().uuidString, tripID: String, latitude: Double, longitude: Double, timestamp: Date = Date(), speed: Double) {
        self.id = id
        self.tripID = tripID
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
    }
}

```

## Trip

Source: FMS/Models/Trip.swift

```swift
import Foundation

public struct Trip: Codable, Identifiable {
    public var id: String
    public var vehicleId: String?
    public var driverId: String?
    public var assignmentId: String?
    public var shipmentDescription: String?
    public var shipmentWeightKg: Double?
    public var shipmentPackageCount: Int?
    public var fragile: Bool?
    public var specialInstructions: String?
    public var startLat: Double?
    public var startLng: Double?
    public var startName: String?
    public var endLat: Double?
    public var endLng: Double?
    public var endName: String?
    public var distanceKm: Double?
    public var estimatedDurationMin: Int?
    public var actualDurationMin: Int?
    public var fuelUsedLiters: Double?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date?
    public var startTime: Date?
    public var endTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case assignmentId = "assignment_id"
        case shipmentDescription = "shipment_description"
        case shipmentWeightKg = "shipment_weight_kg"
        case shipmentPackageCount = "shipment_package_count"
        case fragile
        case specialInstructions = "special_instructions"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case startName = "start_name"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case endName = "end_name"
        case distanceKm = "distance_km"
        case estimatedDurationMin = "estimated_duration_min"
        case actualDurationMin = "actual_duration_min"
        case fuelUsedLiters = "fuel_used_liters"
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

```

## TripGPSLog

Source: FMS/Models/TripGPSLog.swift

```swift
import Foundation

public struct TripGPSLog: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var lat: Double?
    public var lng: Double?
    public var speed: Double?
    public var heading: Double?
    public var recordedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case lat
        case lng
        case speed
        case heading
        case recordedAt = "recorded_at"
    }
}

```

## TripStop

Source: FMS/Models/TripStop.swift

```swift
import Foundation

public struct TripStop: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var name: String?
    public var lat: Double?
    public var lng: Double?
    public var stopType: String?
    public var goodsDescription: String?
    public var packages: Int?
    public var weightKg: Double?
    public var receiverName: String?
    public var signatureUrl: String?
    public var photoUrl: String?
    public var deliveredAt: Date?
    public var sequenceNumber: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case name
        case lat
        case lng
        case stopType = "stop_type"
        case goodsDescription = "goods_description"
        case packages
        case weightKg = "weight_kg"
        case receiverName = "receiver_name"
        case signatureUrl = "signature_url"
        case photoUrl = "photo_url"
        case deliveredAt = "delivered_at"
        case sequenceNumber = "sequence_number"
    }
}

```

## User

Source: FMS/Models/User.swift

```swift
import Foundation

public struct User: Codable, Identifiable {
    public var id: String
    public var name: String?
    public var email: String?
    public var phone: String?
    public var role: String?
    public var status: String?
    public var licenseNumber: String?
    public var licenseExpiry: Date?
    public var createdBy: String?
    public var createdAt: Date?
    public var lastLogin: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case role
        case status
        case licenseNumber = "license_number"
        case licenseExpiry = "license_expiry"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }
}

```

## Vehicle

Source: FMS/Models/Vehicle.swift

```swift
import Foundation

public struct Vehicle: Codable, Identifiable {
    public var id: String
    public var plateNumber: String?
    public var chassisNumber: String?
    public var manufacturer: String?
    public var model: String?
    public var fuelType: String?
    public var fuelTankCapacity: Double?
    public var carryingCapacity: Double?
    public var purchaseDate: Date?
    public var odometer: Double?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber = "plate_number"
        case chassisNumber = "chassis_number"
        case manufacturer
        case model
        case fuelType = "fuel_type"
        case fuelTankCapacity = "fuel_tank_capacity"
        case carryingCapacity = "carrying_capacity"
        case purchaseDate = "purchase_date"
        case odometer
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

```

## VehicleDocument

Source: FMS/Models/VehicleDocument.swift

```swift
import Foundation

public struct VehicleDocument: Codable, Identifiable {
    public var id: String
    public var vehicleId: String?
    public var documentType: String?
    public var fileUrl: String?
    public var expiryDate: Date?
    public var uploadedBy: String?
    public var uploadedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case documentType = "document_type"
        case fileUrl = "file_url"
        case expiryDate = "expiry_date"
        case uploadedBy = "uploaded_by"
        case uploadedAt = "uploaded_at"
    }
}

```

## VehicleEvent

Source: FMS/Models/VehicleEvent.swift

```swift
import Foundation

public enum EventType: String, Codable {
    case harshBraking = "HarshBraking"
    case rapidAcceleration = "RapidAcceleration"
    case maintenanceAlert = "MaintenanceAlert"
    case highGImpact = "HighGImpact"
}

public struct VehicleEvent: Codable, Identifiable {
    public var id: String
    public var vehicleID: String
    public var tripID: String?
    public var eventType: EventType
    public var timestamp: Date
    
    public init(id: String = UUID().uuidString, vehicleID: String, tripID: String? = nil, eventType: EventType, timestamp: Date = Date()) {
        self.id = id
        self.vehicleID = vehicleID
        self.tripID = tripID
        self.eventType = eventType
        self.timestamp = timestamp
    }
}

```

## VehicleInspection

Source: FMS/Models/VehicleInspection.swift

```swift
import Foundation

// Assuming image_urls comes back as an array of strings natively in JSON or as data. We will map to [String]? for JSON compatibility.
public struct VehicleInspection: Codable, Identifiable {
    public var id: String
    public var vehicleId: String?
    public var driverId: String?
    public var inspectionType: String?
    public var brakesOk: Bool?
    public var tiresOk: Bool?
    public var headlightsOk: Bool?
    public var mirrorsOk: Bool?
    public var engineOk: Bool?
    public var issuesReported: String?
    public var imageUrls: [String]?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case inspectionType = "inspection_type"
        case brakesOk = "brakes_ok"
        case tiresOk = "tires_ok"
        case headlightsOk = "headlights_ok"
        case mirrorsOk = "mirrors_ok"
        case engineOk = "engine_ok"
        case issuesReported = "issues_reported"
        case imageUrls = "image_urls"
        case createdAt = "created_at"
    }
}

```

