import SwiftUI

struct MainTabView: View {
    @StateObject private var loc = LocaleManager.shared

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(loc.tabHome, systemImage: "house.fill") }
            GroupListView()
                .tabItem { Label(loc.tabGroups, systemImage: "list.bullet.rectangle") }
            JoinGroupView()
                .tabItem { Label(loc.tabJoin, systemImage: "person.badge.plus") }
            ProfileView()
                .tabItem { Label(loc.tabProfile, systemImage: "person.circle") }
        }
        .tint(.accentColor)
    }
}
