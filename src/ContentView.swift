import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ContentView")

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isNavigationActive = false  // 상세 페이지 진입 시 탭바 스와이프 비활성화용

    var body: some View {
        ZStack(alignment: .bottom) {
            // 페이지 콘텐츠
            TabView(selection: $selectedTab) {
                HomeView(isNavigationActive: $isNavigationActive)
                    .tag(0)

                RecordsView()
                    .tag(1)

                SettingsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))  // 스와이프 전환, 인디케이터 숨김
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .allowsHitTesting(true)  // 항상 터치 허용
            .scrollDisabled(isNavigationActive)  // 상세 페이지에서는 탭 스와이프만 비활성화

            // 커스텀 하단 탭바
            CustomTabBar(selectedIndex: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            logger.info("🚀 [ContentView] 앱 메인 화면 나타남")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            let tabNames = ["홈", "기록", "설정"]
            logger.info("🚀 [ContentView] 탭 변경: \(tabNames[oldValue]) → \(tabNames[newValue])")
        }
        .onChange(of: isNavigationActive) { _, newValue in
            logger.info("🚀 [ContentView] 네비게이션 상태 변경: \(newValue ? "상세 페이지" : "홈")")
        }
    }
}

#Preview {
    ContentView()
}
