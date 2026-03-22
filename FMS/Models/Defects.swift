//
//  Defects.swift
//  FMS
//
//  Created by Devvvv on 13/03/26.
//

import Foundation

public struct Defect: Codable, Identifiable {
    public var id: String
    public var vehicleId: String
    public var reportedBy: String?
    public var workOrderId: String?
    public var title: String
    public var description: String?
    public var category: String?
    public var priority: String?
    public var status: String?
    public var reportedAt: Date?
    public var resolvedAt: Date?
    public var tripId: String?
    public var imageUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId   = "vehicle_id"
        case reportedBy  = "reported_by"
        case workOrderId = "work_order_id"
        case title
        case description
        case category
        case priority
        case status
        case reportedAt  = "reported_at"
        case resolvedAt  = "resolved_at"
        case tripId      = "trip_id"
        case imageUrls   = "image_urls"
    }
}

/// Insert-only model — omits `id` so Supabase auto-generates the UUID.
public struct DefectInsert: Codable {
    public var id: String?
    public var vehicleId: String
    public var reportedBy: String?
    public var tripId: String?
    public var title: String
    public var description: String?
    public var category: String?
    public var priority: String?
    public var status: String?
    public var reportedAt: Date?
    public var imageUrls: [String]?

    public init(
        id: String? = nil,
        vehicleId: String,
        reportedBy: String? = nil,
        tripId: String? = nil,
        title: String,
        description: String? = nil,
        category: String? = nil,
        priority: String? = nil,
        status: String? = "open",
        reportedAt: Date? = Date(),
        imageUrls: [String]? = nil
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.reportedBy = reportedBy
        self.tripId = tripId
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.status = status
        self.reportedAt = reportedAt
        self.imageUrls = imageUrls
    }

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId  = "vehicle_id"
        case reportedBy = "reported_by"
        case tripId     = "trip_id"
        case title
        case description
        case category
        case priority
        case status
        case reportedAt = "reported_at"
        case imageUrls  = "image_urls"
    }
}
