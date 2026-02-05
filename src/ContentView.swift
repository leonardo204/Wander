import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ContentView")

// MARK: - ContentView
// Related: CustomTabBar.swift (탭바 UI), HomeView.swift (홈 탭), RecordsView.swift (기록 탭)

/// 앱의 메인 컨테이너 뷰 - 탭 네비게이션 관리
/// - NOTE: TabView의 .page 스타일로 스와이프 전환 지원
/// - IMPORTANT: 상세 페이지 진입 시 탭 스와이프 비활성화 (isNavigationActive)
struct ContentView: View {
    @State private var selectedTab = 0

    /// 상세 페이지 진입 상태 - true면 탭 스와이프 비활성화
    /// - NOTE: HomeView의 navigationPath가 비어있지 않으면 true
    @State private var isNavigationActive = false

    /// 홈 탭 네비게이션 리셋 트리거
    /// - NOTE: 같은 탭 클릭 시 값을 변경하여 HomeView에서 navigationPath 초기화 유도
    @State private var homeResetTrigger = false

    /// 탭바 높이 (safe area 포함)
    private let tabBarHeight: CGFloat = 49

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 페이지 콘텐츠
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
                .tabViewStyle(.page(indexDisplayMode: .never))  // 스와이프 전환, 인디케이터 숨김
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                .allowsHitTesting(true)  // 항상 터치 허용
                .scrollDisabled(isNavigationActive)  // 상세 페이지에서는 탭 스와이프만 비활성화

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
