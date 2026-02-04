import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "CustomTabBar")

/// Parchment PageView와 함께 사용하는 커스텀 하단 탭바
struct CustomTabBar: View {
    // MARK: - Properties

    @Binding var selectedIndex: Int

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
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedIndex = index
                            }
                            logger.info("🚀 [CustomTabBar] 탭 선택: \(tabs[index].titleKey)")
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
