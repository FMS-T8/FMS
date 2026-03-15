import Foundation

public struct VehicleDocument: Codable, Identifiable {
    public var id: String
    public var vehicleId: String
    public var documentType: String
    public var fileUrl: String
    public var expiryDate: Date?
    public var issueDate: Date?
    public var uploadedBy: String?
    public var uploadedAt: Date?

    // Insurance
    public var insuranceCompany: String?
    public var policyNumber: String?
    public var insuranceStatus: String?

    // Registration Certificate (RC)
    public var ownerName: String?
    public var vehicleModel: String?
    public var registrationDate: Date?

    // Permit
    public var permitNumber: String?
    public var permitType: String?

    // PUC & Fitness
    public var certificateNumber: String?

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId        = "vehicle_id"
        case documentType     = "document_type"
        case fileUrl          = "file_url"
        case expiryDate       = "expiry_date"
        case issueDate        = "issue_date"
        case uploadedBy       = "uploaded_by"
        case uploadedAt       = "uploaded_at"
        case insuranceCompany = "insurance_company"
        case policyNumber     = "policy_number"
        case insuranceStatus  = "insurance_status"
        case ownerName        = "owner_name"
        case vehicleModel     = "vehicle_model"
        case registrationDate = "registration_date"
        case permitNumber     = "permit_number"
        case permitType       = "permit_type"
        case certificateNumber = "certificate_number"
        case metadata          = "metadata"
    }

    // Supabase returns date-only columns as "yyyy-MM-dd".
    // This helper tries ISO 8601 full datetime first, then falls back to date-only.
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let raw = try? container.decodeIfPresent(String.self, forKey: key) else { return nil }
        return parseDate(raw)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: raw) { return date }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: raw) { return date }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.date(from: raw)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id               = try container.decode(String.self, forKey: .id)
        vehicleId        = try container.decode(String.self, forKey: .vehicleId)
        documentType     = try container.decode(String.self, forKey: .documentType)
        fileUrl          = try container.decode(String.self, forKey: .fileUrl)
        uploadedBy       = try container.decodeIfPresent(String.self, forKey: .uploadedBy)
        insuranceStatus  = try container.decodeIfPresent(String.self, forKey: .insuranceStatus)

        // Date fields — handle both "yyyy-MM-dd" and full ISO 8601
        expiryDate       = Self.decodeDate(from: container, key: .expiryDate)
        issueDate        = Self.decodeDate(from: container, key: .issueDate)
        uploadedAt       = Self.decodeDate(from: container, key: .uploadedAt)
        registrationDate = Self.decodeDate(from: container, key: .registrationDate)

        // The DB stores extra fields in a metadata jsonb column.
        // Try top-level columns first (future migration); fall back to metadata dict.
        let meta = (try? container.decodeIfPresent([String: String].self, forKey: .metadata)) ?? nil

        func topOrMeta(_ topKey: CodingKeys, _ metaKey: String) -> String? {
            (try? container.decodeIfPresent(String.self, forKey: topKey)) ?? meta?[metaKey]
        }

        func topDateOrMeta(_ topKey: CodingKeys, _ metaKey: String) -> Date? {
            if let d = Self.decodeDate(from: container, key: topKey) { return d }
            if let raw = meta?[metaKey] { return Self.parseDate(raw) }
            return nil
        }

        insuranceCompany  = topOrMeta(.insuranceCompany,  "insurance_company")
        policyNumber      = topOrMeta(.policyNumber,      "policy_number")
        ownerName         = topOrMeta(.ownerName,         "owner_name")
        vehicleModel      = topOrMeta(.vehicleModel,      "vehicle_model")
        permitNumber      = topOrMeta(.permitNumber,      "permit_number")
        permitType        = topOrMeta(.permitType,        "permit_type")
        certificateNumber = topOrMeta(.certificateNumber, "certificate_number")

        // registration_date may be in metadata as a string
        if registrationDate == nil {
            registrationDate = topDateOrMeta(.registrationDate, "registration_date")
        }

        // issue_date may be in metadata for PUC/Fitness
        if issueDate == nil {
            issueDate = topDateOrMeta(.issueDate, "issue_date")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id,           forKey: .id)
        try container.encode(vehicleId,    forKey: .vehicleId)
        try container.encode(documentType, forKey: .documentType)
        try container.encode(fileUrl,      forKey: .fileUrl)
        
        try container.encodeIfPresent(uploadedBy,      forKey: .uploadedBy)
        try container.encodeIfPresent(insuranceStatus, forKey: .insuranceStatus)
        try container.encodeIfPresent(insuranceCompany, forKey: .insuranceCompany)
        try container.encodeIfPresent(policyNumber,      forKey: .policyNumber)
        try container.encodeIfPresent(ownerName,         forKey: .ownerName)
        try container.encodeIfPresent(vehicleModel,      forKey: .vehicleModel)
        try container.encodeIfPresent(permitNumber,      forKey: .permitNumber)
        try container.encodeIfPresent(permitType,        forKey: .permitType)
        try container.encodeIfPresent(certificateNumber, forKey: .certificateNumber)

        let formatter = ISO8601DateFormatter()
        // Standard ISO8601 for dates
        if let d = expiryDate {
            try container.encode(formatter.string(from: d), forKey: .expiryDate)
        }
        if let d = issueDate {
            try container.encode(formatter.string(from: d), forKey: .issueDate)
        }
        if let d = uploadedAt {
            try container.encode(formatter.string(from: d), forKey: .uploadedAt)
        }
        if let d = registrationDate {
            try container.encode(formatter.string(from: d), forKey: .registrationDate)
        }
    }
}
