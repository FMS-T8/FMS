import Foundation

public enum AddVehicleError: Error {
    case duplicatePlate
    case duplicateChassis
    case networkError
    case unknown
}
