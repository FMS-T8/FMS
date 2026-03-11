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
