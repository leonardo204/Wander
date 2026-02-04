import SwiftUI

// MARK: - 글래스모피즘 패널 컴포넌트

/// 반투명 글래스 효과 패널 (iOS 15+ Material 사용)
struct GlassPanelView<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var padding: CGFloat
    var opacity: Double
    var shadowRadius: CGFloat

    init(
        cornerRadius: CGFloat = WanderSpacing.radiusLarge,
        padding: CGFloat = WanderSpacing.space4,
        opacity: Double = 0.7,
        shadowRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.opacity = opacity
        self.shadowRadius = shadowRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // 글래스 효과 (blur + tint)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // 반투명 화이트 오버레이
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(opacity))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: 5)
    }
}

// MARK: - 글래스 스티커 (Story용 작은 패널)

/// Instagram Story용 스티커 형태 글래스 패널
struct GlassStickerView<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat

    init(
        cornerRadius: CGFloat = WanderSpacing.radiusMedium,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, WanderSpacing.space3)
            .padding(.vertical, WanderSpacing.space2)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.6))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - 글래스 버튼

/// 글래스 효과가 적용된 버튼
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isSelected: Bool

    init(
        title: String,
        icon: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: WanderSpacing.space2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(title)
                    .font(WanderTypography.bodySmall)
            }
            .foregroundColor(isSelected ? .white : WanderColors.textPrimary)
            .padding(.horizontal, WanderSpacing.space4)
            .padding(.vertical, WanderSpacing.space3)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                            .fill(WanderColors.primary)
                    } else {
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                            .fill(Color.white.opacity(0.5))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 공유 정보 패널 컨텐츠

/// 공유 이미지 내 정보 표시용 뷰 (글래스 패널 내부)
struct ShareInfoContent: View {
    let title: String
    let placeCount: Int
    let distance: Double
    var showWatermark: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space2) {
            // 제목
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ShareColors.textDark)

            // 통계
            HStack(spacing: WanderSpacing.space4) {
                Label("\(placeCount)곳", systemImage: "mappin")
                Label("\(Int(distance))km", systemImage: "car.fill")
            }
            .font(.system(size: 14))
            .foregroundColor(ShareColors.textDark.opacity(0.8))

            // 워터마크
            if showWatermark {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.system(size: 10))
                        Text("Wander")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(ShareColors.accent)
                }
            }
        }
    }
}

// MARK: - 공유 이미지용 컬러

/// 공유 이미지 렌더링용 컬러 (UIColor 호환)
struct ShareColors {
    /// 다크 텍스트 (글래스 패널 위)
    static let textDark = Color(hex: "#1A2B33")

    /// 악센트 (워터마크, 아이콘)
    static let accent = Color(hex: "#87CEEB")

    /// 글래스 배경 (렌더링용)
    static let glassBackground = Color.white.opacity(0.75)

    /// 그림자 색상
    static let shadow = Color.black.opacity(0.1)
}

// MARK: - Preview

#Preview("Glass Panel") {
    ZStack {
        // 배경 이미지 시뮬레이션
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            // 기본 글래스 패널
            GlassPanelView {
                ShareInfoContent(
                    title: "제주도 3박 4일",
                    placeCount: 8,
                    distance: 156
                )
            }
            .frame(maxWidth: 300)

            // 글래스 스티커
            GlassStickerView {
                HStack(spacing: 8) {
                    Image(systemName: "mappin")
                    Text("8곳 방문")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ShareColors.textDark)
            }

            // 글래스 버튼
            HStack(spacing: 12) {
                GlassButton(title: "Glass", icon: "sparkles", isSelected: true) {}
                GlassButton(title: "Polaroid", icon: "photo") {}
                GlassButton(title: "Minimal", icon: "square") {}
            }
        }
        .padding()
    }
}
