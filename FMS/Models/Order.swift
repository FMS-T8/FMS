//
//  Order.swift
//  FMS
//
//  Created by user@50 on 16/03/26.
//

import Foundation

public struct Order: Codable, Identifiable {
    public let id: String
    public let orderNumber: String?
    public let customerName: String
    public let customerPhone: String?
    public let customerEmail: String?
    public let totalWeightKg: Double
    public let totalPackages: Int?
    public let cargoType: String?
    public let specialInstructions: String?
    public let originName: String?
    public let originLat: Double?
    public let originLng: Double?
    public let destinationName: String?
    public let destinationLat: Double?
    public let destinationLng: Double?
    public let requestedPickupAt: Date?
    public let requestedDeliveryAt: Date?
    public let status: String?
    public let priority: String?
    public let quotedPrice: Double?
    public let finalPrice: Double?
    public let createdBy: String?
    public let createdAt: Date?
    public let amountReceived: Double?
    public let paymentStatus: String?
    public let paymentMethod: String?
    public let invoiceNumber: String?

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber        = "order_number"
        case customerName       = "customer_name"
        case customerPhone      = "customer_phone"
        case customerEmail      = "customer_email"
        case totalWeightKg      = "total_weight_kg"
        case totalPackages      = "total_packages"
        case cargoType          = "cargo_type"
        case specialInstructions = "special_instructions"
        case originName         = "origin_name"
        case originLat          = "origin_lat"
        case originLng          = "origin_lng"
        case destinationName    = "destination_name"
        case destinationLat     = "destination_lat"
        case destinationLng     = "destination_lng"
        case requestedPickupAt  = "requested_pickup_at"
        case requestedDeliveryAt = "requested_delivery_at"
        case status
        case priority
        case quotedPrice        = "quoted_price"
        case finalPrice         = "final_price"
        case createdBy          = "created_by"
        case createdAt          = "created_at"
        case amountReceived     = "amount_received"
        case paymentStatus      = "payment_status"
        case paymentMethod      = "payment_method"
        case invoiceNumber      = "invoice_number"
    }

    // MARK: - Computed

    public var statusLabel: String {
        switch status?.lowercased() {
        case "pending":    return "Pending"
        case "confirmed":  return "Confirmed"
        case "dispatched": return "Dispatched"
        case "in_transit": return "In Transit"
        case "delivered":  return "Delivered"
        case "cancelled":  return "Cancelled"
        default:           return status?.capitalized ?? "Unknown"
        }
    }

    /// Only truly unassigned orders need a driver — "confirmed" means already actioned
    public var isPending: Bool {
        status?.lowercased() == "pending"
    }

    public var isConfirmed: Bool {
        status?.lowercased() == "confirmed"
    }

    public var isOngoing: Bool {
        let s = status?.lowercased()
        return s == "dispatched" || s == "in_transit"
    }

    public var isCompleted: Bool {
        let s = status?.lowercased()
        return s == "delivered" || s == "cancelled"
    }
}
