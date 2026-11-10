import Foundation
import Supabase

/// Gemeinsamer Supabase-Client (Anleitung Backend/ONLINE-IMPLEMENTIERUNG.md, Schritt 6).
/// Ohne Schlüssel in der Info.plist (Config/Secrets.xcconfig fehlt) bleibt `client` nil und die App offline.
enum Backend {
    static let client: SupabaseClient? = {
        guard let url = OnlineConfig.supabaseURL, let key = OnlineConfig.supabaseAnonKey else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
