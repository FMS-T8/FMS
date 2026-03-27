import Foundation
import Supabase
import Network

// MARK: - Queued Payload Types

public enum QueuedPayloadType: String, Codable {
    case sosAlert = "sos_alert"
    case breakLog = "break_log"
    case defect = "defect"
}

public struct QueuedPayload: Codable, Identifiable {
    public let id: String
    public let type: QueuedPayloadType
    public let tableName: String
    public let jsonData: Data
    public let createdAt: Date
    public var retryCount: Int
    public let recordId: String?

    public init(type: QueuedPayloadType, tableName: String, jsonData: Data, recordId: String? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.tableName = tableName
        self.jsonData = jsonData
        self.createdAt = Date()
        self.retryCount = 0
        self.recordId = recordId
    }
}

// MARK: - Offline Queue Service

@MainActor
public final class OfflineQueueService {
    public static let shared = OfflineQueueService()

    private let storageKey = "fms_offline_queue"
    private let maxRetries = 5
    private var networkMonitor: NWPathMonitor?
    private var isProcessing = false

    private init() {
        startNetworkMonitoring()
    }

    // MARK: - Public API

    public func insertOrQueue<T: Encodable>(
        table: String,
        payload: T,
        payloadType: QueuedPayloadType
    ) async -> Bool {
        do {
            try await SupabaseService.shared.client
                .from(table)
                .insert(payload)
                .execute()
            return true
        } catch {
            print("❌ [OfflineQueue] Insert Failed: \(error.localizedDescription)")
            enqueue(table: table, payload: payload, type: payloadType)
            return false
        }
    }

    public func updateOrQueue<T: Encodable>(
        table: String,
        payload: T,
        id: String,
        payloadType: QueuedPayloadType
    ) async -> Bool {
        do {
            try await SupabaseService.shared.client
                .from(table)
                .update(payload)
                .eq("id", value: id)
                .execute()
            return true
        } catch {
            print("❌ [OfflineQueue] Update Failed — queuing for retry: \(error.localizedDescription)")
            enqueue(table: table, payload: payload, type: payloadType, recordId: id)
            return false
        }
    }

    public func enqueue<T: Encodable>(table: String, payload: T, type: QueuedPayloadType, recordId: String? = nil) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let jsonData = try? encoder.encode(payload) else { return }
        let queued = QueuedPayload(type: type, tableName: table, jsonData: jsonData, recordId: recordId)
        
        let queue = loadQueue()
        saveQueue(queue + [queued])
    }

    public func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        let queue = loadQueue()
        var failedItems: [QueuedPayload] = []

        for var item in queue {
            do {
                if let recordId = item.recordId {
                    try await SupabaseService.shared.client
                        .from(item.tableName)
                        .update(AnyJSON(item.jsonData))
                        .eq("id", value: recordId)
                        .execute()
                } else {
                    try await SupabaseService.shared.client
                        .from(item.tableName)
                        .insert(AnyJSON(item.jsonData))
                        .execute()
                }
            } catch {
                item.retryCount += 1
                if item.retryCount < maxRetries {
                    failedItems.append(item)
                }
            }
        }

        saveQueue(failedItems)
        isProcessing = false
    }

    public var pendingCount: Int {
        loadQueue().count
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task { @MainActor [weak self] in
                    await self?.processQueue()
                }
            }
        }
        networkMonitor?.start(queue: DispatchQueue(label: "fms.network.monitor"))
    }

    // MARK: - Persistence

    private func loadQueue() -> [QueuedPayload] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([QueuedPayload].self, from: data)) ?? []
    }

    private func saveQueue(_ queue: [QueuedPayload]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - AnyJSON wrapper for raw data insertion

private struct AnyJSON: Encodable {
    let data: Data

    init(_ data: Data) { self.data = data }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let dict = try JSONSerialization.jsonObject(with: data)
        let reEncoded = try JSONSerialization.data(withJSONObject: dict)
        let json = try JSONDecoder().decode(AnyCodable.self, from: reEncoded)
        try container.encode(json)
    }
}

private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr
        } else if let str = try? container.decode(String.self) {
            value = str
        } else if let num = try? container.decode(Double.self) {
            value = num
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let n as Int: try container.encode(n)
        case let n as Double: try container.encode(n)
        case let s as String: try container.encode(s)
        case let b as Bool: try container.encode(b)
        case let d as [String: AnyCodable]: try container.encode(d)
        case let a as [AnyCodable]: try container.encode(a)
        default: try container.encodeNil()
        }
    }
}
