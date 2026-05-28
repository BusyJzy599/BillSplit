import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()

            #if DEBUG
            let settings = Firestore.firestore().settings
            settings.host = "localhost:8080"
            settings.cacheSettings = MemoryCacheSettings()
            settings.isSSLEnabled = false
            Firestore.firestore().settings = settings

            Auth.auth().useEmulator(withHost: "localhost", port: 9099)
            #endif
        } else {
            // Fallback: no GoogleService-Info.plist — use demo config for UI testing
            let options = FirebaseOptions(
                googleAppID: "1:000000000000:ios:0000000000000000",
                gcmSenderID: "000000000000"
            )
            options.projectID = "demo-billsplit"
            FirebaseApp.configure(options: options)
        }

        return true
    }
}

@main
struct BillSplitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
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
