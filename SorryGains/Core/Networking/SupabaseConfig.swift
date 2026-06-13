import Foundation
import Supabase

enum SupabaseConfig {
    /// Liftly と共通の Supabase プロジェクト URL
    static let url = URL(string: "https://lybgdrxsojuaylnvdmwb.supabase.co")!

    /// Supabase の anon (public) API key
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5Ymdkcnhzb2p1YXlsbnZkbXdiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2MTIyMDAsImV4cCI6MjA4NzE4ODIwMH0.v9mvcsp2zdIHtiOzWJKjHFf2Zi1OjJvXte51JOcifDc"

    /// Google OAuth リダイレクト URL scheme (筋肉ごめん用)
    static let redirectScheme = "com.sorrygains"
    static let redirectURL = URL(string: "\(redirectScheme)://auth/callback")!

    /// 共有 Supabase クライアント
    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}
