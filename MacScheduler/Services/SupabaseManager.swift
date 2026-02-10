import Foundation
import Supabase

actor SupabaseManager {
    static let shared = SupabaseManager()

    static let projectURL = URL(string: "https://jsfjxltvedqhvwkydlkd.supabase.co")!
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpzZmp4bHR2ZWRxaHZ3a3lkbGtkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2MjY4ODEsImV4cCI6MjA4NjIwMjg4MX0.DwT2dQAYOLxjDxKrFqDuf0uZYT6gCVcHqWE4aSwW_l8"

    nonisolated let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.anonKey
        )
    }
}
