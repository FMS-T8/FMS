import Foundation

public struct Vehicle: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var plateNumber: String
    public var chassisNumber: String?
    public var manufacturer: String?
    public var model: String?
    public var fuelType: String?
    public var fuelTankCapacity: Double?
    public var carryingCapacity: Double?
    public var purchaseDate: String?
    public var odometer: Double?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date? 
    
    // Maintenance Prediction
    public var lastServiceDate: Date?
    public var lastServiceOdometer: Double?
    public var serviceIntervalKm: Double?
    public var serviceIntervalMonths: Int?
    public var maintenanceNotes: String?
    
    public var purchaseDate: Date? {
        guard let str = purchaseDateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }
    
    public init(id: String, plateNumber: String, chassisNumber: String, manufacturer: String? = nil, model: String? = nil, fuelType: String = "diesel", fuelTankCapacity: Double = 0.0, carryingCapacity: Double? = nil, purchaseDateString: String? = nil, odometer: Double? = nil, status: String? = nil, createdBy: String? = nil, createdAt: Date? = nil, lastServiceDate: Date? = nil, lastServiceOdometer: Double? = nil, serviceIntervalKm: Double? = nil, serviceIntervalMonths: Int? = nil, maintenanceNotes: String? = nil) {
        self.id = id
        self.plateNumber = plateNumber
        self.chassisNumber = chassisNumber
        self.manufacturer = manufacturer
        self.model = model
        self.fuelType = fuelType
        self.fuelTankCapacity = fuelTankCapacity
        self.carryingCapacity = carryingCapacity
        self.purchaseDateString = purchaseDateString
        self.odometer = odometer
        self.status = status
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.lastServiceDate = lastServiceDate
        self.lastServiceOdometer = lastServiceOdometer
        self.serviceIntervalKm = serviceIntervalKm
        self.serviceIntervalMonths = serviceIntervalMonths
        self.maintenanceNotes = maintenanceNotes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        plateNumber = try container.decode(String.self, forKey: .plateNumber)
        
        // Handle potential nulls with defaults
        chassisNumber = try container.decodeIfPresent(String.self, forKey: .chassisNumber) ?? ""
        fuelType = try container.decodeIfPresent(String.self, forKey: .fuelType) ?? "diesel"
        fuelTankCapacity = try container.decodeIfPresent(Double.self, forKey: .fuelTankCapacity) ?? 0.0
        
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        carryingCapacity = try container.decodeIfPresent(Double.self, forKey: .carryingCapacity)
        purchaseDateString = try container.decodeIfPresent(String.self, forKey: .purchaseDateString)
        odometer = try container.decodeIfPresent(Double.self, forKey: .odometer)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        
        lastServiceDate = try container.decodeIfPresent(Date.self, forKey: .lastServiceDate)
        lastServiceOdometer = try container.decodeIfPresent(Double.self, forKey: .lastServiceOdometer)
        serviceIntervalKm = try container.decodeIfPresent(Double.self, forKey: .serviceIntervalKm)
        serviceIntervalMonths = try container.decodeIfPresent(Int.self, forKey: .serviceIntervalMonths)
        maintenanceNotes = try container.decodeIfPresent(String.self, forKey: .maintenanceNotes)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber          = "plate_number"
        case chassisNumber        = "chassis_number"
        case manufacturer
        case model
        case fuelType             = "fuel_type"
        case fuelTankCapacity     = "fuel_tank_capacity"
        case carryingCapacity     = "carrying_capacity"
        case purchaseDate         = "purchase_date"
        case odometer
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
        
        case lastServiceDate = "last_service_date"
        case lastServiceOdometer = "last_service_odometer"
        case serviceIntervalKm = "service_interval_km"
        case serviceIntervalMonths = "service_interval_months"
        case maintenanceNotes = "maintenance_notes"
    }
}

public struct OverrideUpdate: Encodable {
    public let service_interval_km: Double?
    public let service_interval_months: Int?
    
    public init(service_interval_km: Double?, service_interval_months: Int?) {
        self.service_interval_km = service_interval_km
        self.service_interval_months = service_interval_months
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Explicitly encoding nil to ensure it's sent as 'null' in JSON, not omitted
        try container.encode(service_interval_km, forKey: .service_interval_km)
        try container.encode(service_interval_months, forKey: .service_interval_months)
    }
    
    enum CodingKeys: String, CodingKey {
        case service_interval_km = "service_interval_km"
        case service_interval_months = "service_interval_months"
    }
}
