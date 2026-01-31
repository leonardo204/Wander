import SwiftUI

enum WanderColors {
    // MARK: - Primary
    static let primary = Color(red: 0.529, green: 0.808, blue: 0.922)      // #87CEEB
    static let primaryLight = Color(red: 0.690, green: 0.878, blue: 0.941) // #B0E0F0
    static let primaryPale = Color(red: 0.910, green: 0.965, blue: 0.992)  // #E8F6FC
    static let primaryDark = Color(red: 0.357, green: 0.639, blue: 0.753)  // #5BA3C0

    // MARK: - Background & Surface
    static let background = Color.white                                     // #FFFFFF
    static let surface = Color(red: 0.973, green: 0.984, blue: 0.992)      // #F8FBFD
    static let surfaceElevated = Color.white                               // #FFFFFF
    static let border = Color(red: 0.898, green: 0.933, blue: 0.949)       // #E5EEF2
    static let borderStrong = Color(red: 0.784, green: 0.851, blue: 0.878) // #C8D9E0

    // MARK: - Text
    static let textPrimary = Color(red: 0.102, green: 0.169, blue: 0.200)   // #1A2B33
    static let textSecondary = Color(red: 0.353, green: 0.420, blue: 0.451) // #5A6B73
    static let textTertiary = Color(red: 0.541, green: 0.608, blue: 0.639)  // #8A9BA3
    static let textDisabled = Color(red: 0.722, green: 0.784, blue: 0.816)  // #B8C8D0

    // MARK: - Semantic
    static let success = Color(red: 0.298, green: 0.686, blue: 0.314)       // #4CAF50
    static let successBackground = Color(red: 0.910, green: 0.961, blue: 0.914) // #E8F5E9
    static let warning = Color(red: 1.0, green: 0.596, blue: 0.0)           // #FF9800
    static let warningBackground = Color(red: 1.0, green: 0.953, blue: 0.878) // #FFF3E0
    static let error = Color(red: 0.957, green: 0.263, blue: 0.212)         // #F44336
    static let errorBackground = Color(red: 1.0, green: 0.922, blue: 0.933) // #FFEBEE
    static let info = Color(red: 0.129, green: 0.588, blue: 0.953)          // #2196F3
    static let infoBackground = Color(red: 0.890, green: 0.949, blue: 0.992) // #E3F2FD

    // MARK: - Activity Labels (Pastel)
    static let activityCafe = Color(red: 0.961, green: 0.902, blue: 0.827)       // #F5E6D3
    static let activityRestaurant = Color(red: 1.0, green: 0.894, blue: 0.882)   // #FFE4E1
    static let activityBeach = Color(red: 0.878, green: 0.957, blue: 0.973)      // #E0F4F8
    static let activityMountain = Color(red: 0.910, green: 0.961, blue: 0.914)   // #E8F5E9
    static let activityTourist = Color(red: 1.0, green: 0.973, blue: 0.882)      // #FFF8E1
    static let activityShopping = Color(red: 0.988, green: 0.894, blue: 0.925)   // #FCE4EC
    static let activityCulture = Color(red: 0.929, green: 0.906, blue: 0.965)    // #EDE7F6
    static let activityAirport = Color(red: 0.925, green: 0.937, blue: 0.945)    // #ECEFF1

    // MARK: - Tab Bar
    static let tabActive = primary
    static let tabInactive = textTertiary
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
