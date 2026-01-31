import SwiftUI

enum WanderSpacing {
    // MARK: - Base Spacing (4pt unit)
    static let space0: CGFloat = 0
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space7: CGFloat = 32
    static let space8: CGFloat = 40
    static let space9: CGFloat = 48
    static let space10: CGFloat = 64

    // MARK: - Screen Margins
    static let screenMargin: CGFloat = 20

    // MARK: - Border Radius
    static let radiusNone: CGFloat = 0
    static let radiusSmall: CGFloat = 4      // Tags, badges
    static let radiusMedium: CGFloat = 8     // Buttons, inputs
    static let radiusLarge: CGFloat = 12     // Cards, thumbnails
    static let radiusXL: CGFloat = 16        // Modals, sheets
    static let radiusXXL: CGFloat = 20       // Large cards
    static let radiusFull: CGFloat = 9999    // Circular

    // MARK: - Component Heights
    static let buttonHeight: CGFloat = 52
    static let inputHeight: CGFloat = 48
    static let tabBarHeight: CGFloat = 49
    static let navigationBarHeight: CGFloat = 44

    // MARK: - Icon Sizes
    static let iconSmall: CGFloat = 16
    static let iconMedium: CGFloat = 20
    static let iconLarge: CGFloat = 24
    static let iconXL: CGFloat = 28
    static let iconXXL: CGFloat = 32
    static let iconHuge: CGFloat = 48
}

// MARK: - View Extension for Shadows
extension View {
    func elevation1() -> some View {
        self.shadow(
            color: Color.black.opacity(0.08),
            radius: 3,
            x: 0,
            y: 1
        )
    }

    func elevation2() -> some View {
        self.shadow(
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    func elevation3() -> some View {
        self.shadow(
            color: Color.black.opacity(0.16),
            radius: 24,
            x: 0,
            y: 8
        )
    }
}
