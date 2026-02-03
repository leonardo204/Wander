import SwiftUI
import Parchment
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ContentView")

struct ContentView: View {
    @State private var selectedIndex = 0
    @State private var isNavigationActive = false  // 상세 페이지 진입 시 탭바 스와이프 비활성화용

    var body: some View {
        VStack(spacing: 0) {
            // 스와이프 가능한 페이지 영역
            PageView(selectedIndex: $selectedIndex) {
                Page("홈") {
                    HomeView(isNavigationActive: $isNavigationActive)
                }
                Page("기록") {
                    RecordsView()
                }
                Page("설정") {
                    SettingsView()
                }
            }
            .menuItemSize(.fixed(width: 0, height: 0))  // Parchment 기본 메뉴 숨김 (커스텀 탭바 사용)
            .contentInteraction(isNavigationActive ? .none : .scrolling)  // 상세 페이지에서는 스와이프 비활성화

            // 커스텀 하단 탭바
            CustomTabBar(selectedIndex: $selectedIndex)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            logger.info("🚀 [ContentView] 앱 메인 화면 나타남")
        }
        .onChange(of: selectedIndex) { oldValue, newValue in
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
