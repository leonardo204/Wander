import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ContentView")

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var homeNavigationTrigger = UUID()
    @State private var recordsNavigationTrigger = UUID()
    @State private var settingsNavigationTrigger = UUID()

    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                // 같은 탭을 다시 탭하면 루트로 이동
                if newValue == selectedTab {
                    resetNavigationForTab(newValue)
                }
                selectedTab = newValue
            }
        )) {
            HomeView()
                .id(homeNavigationTrigger)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("홈")
                }
                .tag(0)

            RecordsView()
                .id(recordsNavigationTrigger)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "book.fill" : "book")
                    Text("기록")
                }
                .tag(1)

            SettingsView()
                .id(settingsNavigationTrigger)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                    Text("설정")
                }
                .tag(2)
        }
        .tint(WanderColors.primary)
        .onAppear {
            logger.info("🚀 [ContentView] 앱 메인 화면 나타남")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            let tabNames = ["홈", "기록", "설정"]
            logger.info("🚀 [ContentView] 탭 변경: \(tabNames[oldValue]) → \(tabNames[newValue])")
        }
    }

    private func resetNavigationForTab(_ tab: Int) {
        logger.info("🚀 [ContentView] 탭 \(tab) 네비게이션 리셋")
        switch tab {
        case 0:
            homeNavigationTrigger = UUID()
        case 1:
            recordsNavigationTrigger = UUID()
        case 2:
            settingsNavigationTrigger = UUID()
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}
