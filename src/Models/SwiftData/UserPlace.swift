import Foundation
import SwiftData
import SwiftUI
import CoreLocation

@Model
final class UserPlace {
    var id: UUID
    var name: String
    var icon: String  // emoji
    var latitude: Double
    var longitude: Double
    var address: String
    var isDefault: Bool  // 집, 회사/학교
    var order: Int
    var createdAt: Date

    init(
        name: String,
        icon: String,
        latitude: Double,
        longitude: Double,
        address: String,
        isDefault: Bool = false,
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.isDefault = isDefault
        self.order = order
        self.createdAt = Date()
    }

    /// CLLocationCoordinate2D로 변환
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 좌표 설정
    func setCoordinate(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    /// 두 좌표 간의 거리 (미터 단위)
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }

    /// 기본 장소 (집, 회사/학교) 목록 생성
    static func createDefaultPlaces() -> [UserPlace] {
        [
            UserPlace(
                name: "집",
                icon: "🏠",
                latitude: 0,
                longitude: 0,
                address: "",
                isDefault: true,
                order: 0
            ),
            UserPlace(
                name: "회사/학교",
                icon: "🏢",
                latitude: 0,
                longitude: 0,
                address: "",
                isDefault: true,
                order: 1
            )
        ]
    }

    /// 장소 아이콘 프리셋
    static let iconPresets: [String] = [
        "🏠", "🏢", "🏫", "🏥",
        "🏪", "🏬", "🏛️", "⛪",
        "🏟️", "🎪", "🎬", "🏖️",
        "🏔️", "🌳", "🍽️", "☕"
    ]

    /// 매칭 반경 (미터)
    static let matchingRadius: CLLocationDistance = 100
}
