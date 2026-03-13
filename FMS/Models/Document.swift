import SwiftUI

enum DocumentType: String, CaseIterable, Identifiable, Codable {
    case drivingLicense = "driving_license"
    case governmentId = "government_id"
    case vehicleRegistration = "vehicle_registration"
    case insurance = "insurance"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .drivingLicense: return "Driving License"
        case .governmentId: return "Government ID"
        case .vehicleRegistration: return "Vehicle Registration"
        case .insurance: return "Insurance"
        }
    }

    var icon: String {
        switch self {
        case .drivingLicense: return "doc.text.fill"
        case .governmentId: return "person.text.rectangle.fill"
        case .vehicleRegistration: return "car.fill"
        case .insurance: return "shield.checkered"
        }
    }
}

enum DocumentStatus: String, Codable {
    case active, verified, pending, expired

    var label: String {
        switch self {
        case .active: return "ACTIVE"
        case .verified: return "VERIFIED"
        case .pending: return "PENDING"
        case .expired: return "EXPIRED"
        }
    }

    var color: Color {
        switch self {
        case .active: return FMSTheme.alertGreen
        case .verified: return Color.blue
        case .pending: return FMSTheme.alertAmber
        case .expired: return FMSTheme.alertRed
        }
    }
}

struct UploadedDocument: Identifiable, Codable {
    var id: String = UUID().uuidString
    var type: DocumentType
    var name: String
    var subtitle: String
    var status: DocumentStatus
}
