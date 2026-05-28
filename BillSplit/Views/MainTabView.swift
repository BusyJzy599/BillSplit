import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            GroupListView()
                .tabItem {
                    Label("账单组", systemImage: "list.bullet.rectangle")
                }
            JoinGroupView()
                .tabItem {
                    Label("加入", systemImage: "person.badge.plus")
                }
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
        }
        .tint(.accentColor)
    }
}
