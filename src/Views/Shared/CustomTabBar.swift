import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "CustomTabBar")

// MARK: - CustomTabBar
// Related: ContentView.swift (탭 선택 상태), HomeView.swift (네비게이션 리셋)

/// Parchment PageView와 함께 사용하는 커스텀 하단 탭바
/// - NOTE: 같은 탭을 다시 클릭하면 onSameTabTap 콜백 호출 (초기 화면으로 돌아가기 위함)
struct CustomTabBar: View {
    // MARK: - Properties

    @Binding var selectedIndex: Int

    /// 같은 탭을 다시 클릭했을 때 호출되는 콜백
    /// - IMPORTANT: 상세 페이지에서 탭을 클릭하면 해당 탭의 초기 화면으로 돌아가야 함
    /// - Parameter: 클릭된 탭 인덱스 (0: 홈, 1: 기록, 2: 설정)
    var onSameTabTap: ((Int) -> Void)?

    private var tabs: [(icon: String, selectedIcon: String, titleKey: String)] {
        [
            ("house", "house.fill", "tab.home"),
            ("book", "book.fill", "tab.records"),
            ("gearshape", "gearshape.fill", "tab.settings")
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 상단 구분선
            Rectangle()
                .fill(WanderColors.border)
                .frame(height: 0.5)

            // 탭바 아이템들
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    TabBarItem(
                        icon: selectedIndex == index ? tabs[index].selectedIcon : tabs[index].icon,
                        title: tabs[index].titleKey.localized,
                        isSelected: selectedIndex == index
                    ) {
                        if selectedIndex != index {
                            // 다른 탭으로 전환
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedIndex = index
                            }
                            logger.info("🚀 [CustomTabBar] 탭 전환: \(tabs[index].titleKey)")
                        } else {
                            // NOTE: 같은 탭 클릭 → 해당 탭의 네비게이션 스택을 초기화하여 루트로 이동
                            logger.info("🚀 [CustomTabBar] 같은 탭 클릭 → 초기화: \(tabs[index].titleKey)")
                            onSameTabTap?(index)
                        }
                    }
                }
            }
            .frame(height: 49)  // iOS 표준 탭바 높이
        }
        .background(WanderColors.surface)
    }
}

// MARK: - TabBarItem

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(isSelected ? WanderColors.primary : WanderColors.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedIndex: .constant(0))
    }
}
