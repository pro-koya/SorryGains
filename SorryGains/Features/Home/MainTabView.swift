import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: String {
        case home
        case sage
        case history
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(
                        String(localized: "tab.home"),
                        systemImage: "figure.strengthtraining.traditional"
                    )
                }
                .tag(Tab.home)

            SageView()
                .tabItem {
                    Label(
                        String(localized: "tab.sage"),
                        systemImage: "figure.mind.and.body"
                    )
                }
                .tag(Tab.sage)

            HistoryView()
                .tabItem {
                    Label(
                        String(localized: "tab.history"),
                        systemImage: "calendar"
                    )
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label(
                        String(localized: "tab.settings"),
                        systemImage: "gearshape"
                    )
                }
                .tag(Tab.settings)
        }
        .tint(Color.SG.accent)
    }
}
