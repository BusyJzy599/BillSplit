import SwiftUI
import Supabase

// MARK: - Supabase Client (configure with your Supabase project)

// Replace with your Supabase URL and anon key from https://supabase.com/dashboard
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://YOUR_PROJECT_ID.supabase.co")!,
    supabaseKey: "YOUR_ANON_KEY"
)

// MARK: - App

@main
struct BillSplitApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authVM.isLoggedIn {
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
