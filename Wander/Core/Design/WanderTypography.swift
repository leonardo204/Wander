import SwiftUI

enum WanderTypography {
    // MARK: - Display & Titles
    static let display = Font.system(size: 34, weight: .bold)
    static let title1 = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 22, weight: .bold)
    static let title3 = Font.system(size: 20, weight: .semibold)

    // MARK: - Body
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let bodySmall = Font.system(size: 15, weight: .regular)

    // MARK: - Caption & Footnote
    static let caption1 = Font.system(size: 13, weight: .regular)
    static let caption2 = Font.system(size: 12, weight: .regular)
    static let footnote = Font.system(size: 11, weight: .regular)
}

// MARK: - View Extension for Typography
extension View {
    func wanderDisplay() -> some View {
        self.font(WanderTypography.display)
            .foregroundColor(WanderColors.textPrimary)
    }

    func wanderTitle1() -> some View {
        self.font(WanderTypography.title1)
            .foregroundColor(WanderColors.textPrimary)
    }

    func wanderTitle2() -> some View {
        self.font(WanderTypography.title2)
            .foregroundColor(WanderColors.textPrimary)
    }

    func wanderTitle3() -> some View {
        self.font(WanderTypography.title3)
            .foregroundColor(WanderColors.textPrimary)
    }

    func wanderHeadline() -> some View {
        self.font(WanderTypography.headline)
            .foregroundColor(WanderColors.textPrimary)
    }

    func wanderBody() -> some View {
        self.font(WanderTypography.body)
            .foregroundColor(WanderColors.textPrimary)
    }

    func wanderBodySecondary() -> some View {
        self.font(WanderTypography.body)
            .foregroundColor(WanderColors.textSecondary)
    }

    func wanderCaption() -> some View {
        self.font(WanderTypography.caption1)
            .foregroundColor(WanderColors.textSecondary)
    }
}
