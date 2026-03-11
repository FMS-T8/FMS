import Foundation

/// Protocol defining the public API expected from the Supabase client.
/// This ensures callers can depend on a consistent type regardless of whether
/// the actual Supabase package is linked.
public protocol SupabaseClientType {}

#if canImport(Supabase)
import Supabase

// Extend the real SupabaseClient to conform to our protocol
extension SupabaseClient: SupabaseClientType {}
#else
/// A graceful fallback stub for when the 'supabase-swift' package is not yet linked.
public struct DummySupabaseClient: SupabaseClientType {
    public init() {
        print("⚠️ Supabase SDK is not imported. Please add 'https://github.com/supabase-community/supabase-swift' via Swift Package Manager to enable database functionality.")
    }
}
#endif

/// A shared service that provides access to the Supabase client instance.
public final class SupabaseService {
    public static let shared = SupabaseService()
    
    // The public property type remains identical across compilation paths
    public let client: any SupabaseClientType
    
    private init() {
        #if canImport(Supabase)
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.fullURL,
            supabaseKey: SupabaseConfig.publishableKey
        )
        #else
        self.client = DummySupabaseClient()
        #endif
    }
}
