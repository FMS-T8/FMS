import Foundation
import Supabase

/// A shared service that provides access to the Supabase client instance.
public final class SupabaseService {
    public static let shared = SupabaseService()

    public let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.fullURL,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }
}

// MARK: - Supabase JSON Decoder

extension JSONDecoder {
    /// A decoder configured for Supabase `timestamptz` columns,
    /// which may include fractional seconds (e.g. `.611Z`).
    static func supabase() -> JSONDecoder {
        let decoder = JSONDecoder()
        let fractional = DateFormatter()
        fractional.locale = Locale(identifier: "en_US_POSIX")
        fractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        let plain = DateFormatter()
        plain.locale = Locale(identifier: "en_US_POSIX")
        plain.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = fractional.date(from: str) { return date }
            if let date = plain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(str)"
            )
        }
        return decoder
    }
}
