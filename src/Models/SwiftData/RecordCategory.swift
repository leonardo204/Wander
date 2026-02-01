import Foundation
import SwiftData
import SwiftUI

@Model
final class RecordCategory {
    var id: UUID
    var name: String
    var icon: String  // emoji
    var colorHex: String
    var isDefault: Bool
    var isHidden: Bool
    var order: Int
    var createdAt: Date

    /// 이 카테고리에 속한 기록들
    var records: [TravelRecord] = []

    init(
        name: String,
        icon: String,
        colorHex: String,
        isDefault: Bool = false,
        isHidden: Bool = false,
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.isHidden = isHidden
        self.order = order
        self.createdAt = Date()
    }

    /// SwiftUI Color로 변환
    var color: Color {
        Color(hex: colorHex)
    }

    /// 기본 카테고리 목록 생성
    static func createDefaultCategories() -> [RecordCategory] {
        [
            RecordCategory(name: "여행", icon: "✈️", colorHex: "#87CEEB", isDefault: true, order: 0),
            RecordCategory(name: "일상", icon: "🏠", colorHex: "#98D8AA", isDefault: true, order: 1),
            RecordCategory(name: "주간", icon: "📅", colorHex: "#F7C8E0", isDefault: true, order: 2),
            RecordCategory(name: "출장", icon: "💼", colorHex: "#B4B4B8", isDefault: true, order: 3)
        ]
    }

    /// 카테고리 색상 프리셋
    static let colorPresets: [String] = [
        "#87CEEB", // Sky Blue
        "#98D8AA", // Mint Green
        "#F7C8E0", // Pink
        "#FFD93D", // Yellow
        "#FF6B6B", // Coral
        "#C9B1FF", // Lavender
        "#B4B4B8", // Gray
        "#6BCB77"  // Green
    ]

    /// 카테고리 아이콘 프리셋
    static let iconPresets: [String] = [
        "✈️", "🏠", "📅", "💼",
        "🎉", "🎭", "🏖️", "⛰️",
        "🍽️", "☕", "🛍️", "🎨",
        "🎵", "📸", "🚗", "🚂"
    ]
}
