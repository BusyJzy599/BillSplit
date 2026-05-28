import SwiftUI
import Supabase

// MARK: - Supabase Client (configure with your Supabase project)

// Replace with your Supabase URL and anon key from https://supabase.com/dashboard
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://prmjucdsuejtdxxyucxo.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBybWp1Y2RzdWVqdGR4eHl1Y3hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjM0MjUsImV4cCI6MjA5NTUzOTQyNX0.UgcwvOxXaUoOPyRwnIjnZz8_vkmwfLsZX25_nozhnFw"
)

// MARK: - App

@main
struct BillSplitApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authVM.isLoading {
                ProgressView("加载中...")
            } else if authVM.isLoggedIn {
                MainTabView()
                    .environmentObject(authVM)
            } else {
                LoginView()
                    .environmentObject(authService)
                    .environmentObject(authVM)
            }
        }
    }
}
