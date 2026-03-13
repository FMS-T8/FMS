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
    }
}
