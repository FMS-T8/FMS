import Foundation

#if canImport(Supabase)
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
#else
/// A graceful fallback stub for when the 'supabase-swift' package is not yet linked.
public final class SupabaseService {
    public static let shared = SupabaseService()
    
    private init() {
        print("⚠️ Supabase SDK is not imported. Please add 'https://github.com/supabase-community/supabase-swift' via Swift Package Manager to enable database functionality.")
    }
}
#endif
