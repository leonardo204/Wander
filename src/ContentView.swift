import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ContentView")

// MARK: - ContentView
// Related: CustomTabBar.swift (탭바 UI), HomeView.swift (홈 탭), RecordsView.swift (기록 탭)

/// 앱의 메인 컨테이너 뷰 - 탭 네비게이션 관리
/// - NOTE: 스와이프 또는 탭바 클릭으로 탭 전환 가능
/// - IMPORTANT: 탭 전환 시 항상 각 탭의 초기화면(루트)을 보여줌
struct ContentView: View {
    @State private var selectedTab = 0

    /// 상세 페이지 진입 상태
    /// - NOTE: HomeView의 navigationPath가 비어있지 않으면 true
    @State private var isNavigationActive = false

    /// 홈 탭 네비게이션 리셋 트리거
    /// - NOTE: 탭 전환 또는 같은 탭 클릭 시 값을 변경하여 HomeView에서 navigationPath 초기화 유도
    @State private var homeResetTrigger = false

    /// 탭바 높이 (safe area 포함)
    private let tabBarHeight: CGFloat = 49

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 페이지 콘텐츠
                // NOTE: 스와이프로 탭 전환 가능, 전환 시 각 탭의 초기화면 표시
                TabView(selection: $selectedTab) {
                    HomeView(
                        isNavigationActive: $isNavigationActive,
                        resetTrigger: $homeResetTrigger
                    )
                    .tag(0)

                    RecordsView()
                        .tag(1)

                    SettingsView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedTab)

                // 커스텀 하단 탭바
                VStack(spacing: 0) {
                    CustomTabBar(selectedIndex: $selectedTab) { tappedIndex in
                        // NOTE: 같은 탭을 다시 클릭했을 때 호출됨
                        // 해당 탭의 네비게이션 스택을 초기화하여 루트 화면으로 이동
                        handleSameTabTap(tappedIndex)
                    }
                    // Safe area bottom 영역 채우기
                    Color(WanderColors.surface)
                        .frame(height: geometry.safeAreaInsets.bottom)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            logger.info("🚀 [ContentView] 앱 메인 화면 나타남")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            let tabNames = ["홈", "기록", "설정"]
            logger.info("🚀 [ContentView] 탭 변경: \(tabNames[oldValue]) → \(tabNames[newValue])")

            // IMPORTANT: 탭 전환 시 홈 탭의 네비게이션을 리셋하여 항상 초기화면 표시
            // - 홈에서 다른 탭으로 이동: 홈의 상세 페이지에서 벗어남
            // - 다른 탭에서 홈으로 이동: 홈의 루트 화면 표시
            if oldValue == 0 || newValue == 0 {
                if isNavigationActive {
                    logger.info("🚀 [ContentView] 홈 탭 네비게이션 리셋 (초기화면 표시)")
                    homeResetTrigger.toggle()
                }
            }
        }
        .onChange(of: isNavigationActive) { _, newValue in
            logger.info("🚀 [ContentView] 네비게이션 상태 변경: \(newValue ? "상세 페이지" : "홈")")
        }
    }

    // MARK: - Private Methods

    /// 같은 탭 클릭 시 해당 탭의 네비게이션을 초기화
    /// - Parameter index: 탭 인덱스 (0: 홈, 1: 기록, 2: 설정)
    /// - NOTE: 각 탭의 resetTrigger를 토글하여 자식 뷰에서 navigationPath 초기화 유도
    private func handleSameTabTap(_ index: Int) {
        switch index {
        case 0:
            // 홈 탭: navigationPath 초기화
            homeResetTrigger.toggle()
            logger.info("🚀 [ContentView] 홈 탭 네비게이션 리셋 요청")
        case 1:
            // 기록 탭: 현재 NavigationStack 직접 관리 안 함 (추후 필요시 구현)
            logger.info("🚀 [ContentView] 기록 탭 리셋 (미구현)")
        case 2:
            // 설정 탭: 보통 깊은 네비게이션 없음
            logger.info("🚀 [ContentView] 설정 탭 리셋 (미구현)")
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}
