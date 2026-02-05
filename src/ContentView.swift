import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ContentView")

// MARK: - ContentView
// Related: CustomTabBar.swift (탭바 UI), HomeView.swift (홈 탭), RecordsView.swift (기록 탭)

/// 앱의 메인 컨테이너 뷰 - 탭 네비게이션 관리
/// - NOTE: 상세 페이지에서는 탭 스와이프 완전 비활성화 (탭바 클릭으로만 전환)
/// - IMPORTANT: .page 스타일의 .scrollDisabled()가 불완전하므로 제스처 차단 오버레이 사용
struct ContentView: View {
    @State private var selectedTab = 0

    /// 상세 페이지 진입 상태 - true면 탭 스와이프 완전 비활성화
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
                // NOTE: .page 스타일 제거 - 상세 페이지에서 스와이프 차단이 불완전하므로 탭 클릭으로만 전환
                ZStack {
                    // IMPORTANT: 각 탭 뷰를 ZStack으로 수동 관리하여 스와이프 제스처 완전 차단
                    HomeView(
                        isNavigationActive: $isNavigationActive,
                        resetTrigger: $homeResetTrigger
                    )
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)

                    RecordsView()
                        .opacity(selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 1)

                    SettingsView()
                        .opacity(selectedTab == 2 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 2)
                }
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

            // IMPORTANT: 다른 탭에서 홈 탭으로 전환 시 홈의 네비게이션도 리셋
            // 사용자가 홈 탭 클릭 시 항상 홈의 루트 화면이 보여야 함
            if newValue == 0 && isNavigationActive {
                logger.info("🚀 [ContentView] 홈 탭 전환 시 네비게이션 리셋")
                homeResetTrigger.toggle()
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
