import SwiftUI
import Supabase

// MARK: - Supabase Config

let supabaseURL = URL(string: "https://prmjucdsuejtdxxyucxo.supabase.co")!
let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBybWp1Y2RzdWVqdGR4eHl1Y3hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjM0MjUsImV4cCI6MjA5NTUzOTQyNX0.UgcwvOxXaUoOPyRwnIjnZz8_vkmwfLsZX25_nozhnFw"

let supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)

// MARK: - App

@main
struct BillSplitApp: App {
    @StateObject private var authVM = AuthViewModel()

    init() {
        Task { _ = await ExchangeRateService.shared.fetchLatest() }
    }

    var body: some Scene {
        WindowGroup {
            if authVM.isLoading {
                ZStack {
                    Color(.systemGroupedBackground).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "dollarsign.circle.fill")
                            .resizable().frame(width: 64, height: 64)
                            .foregroundStyle(.tint)
                        Text("BillSplit")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        ProgressView().padding(.top, 8)
                    }
                }
            } else if authVM.isLoggedIn {
                MainTabView().environmentObject(authVM)
            } else {
                LoginView().environmentObject(authVM)
            }
        }
    }
}
