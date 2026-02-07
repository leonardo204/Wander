import Foundation
import SwiftData
import SwiftUI
import CoreLocation
import SwiftyH3

/// 사용자 장소 유형 (v3.1: 회사/학교 분리)
enum UserPlaceType: String, Codable, CaseIterable {
    case home = "home"
    case work = "work"
    case school = "school"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .home: return "집"
        case .work: return "회사"
        case .school: return "학교"
        case .custom: return "기타"
        }
    }

    var icon: String {
        switch self {
        case .home: return "🏠"
        case .work: return "🏢"
        case .school: return "🏫"
        case .custom: return "📍"
        }
    }

    /// Context Classification에서 기준 장소로 사용할지 여부
    var isBaseLocation: Bool {
        switch self {
        case .home, .work, .school: return true
        case .custom: return false
        }
    }
}

@Model
final class UserPlace {
    var id: UUID
    var name: String
    var icon: String  // emoji
    var latitude: Double
    var longitude: Double
    var address: String
    var isDefault: Bool  // 기본 장소 (집/회사/학교)
    var order: Int
    var createdAt: Date

    // MARK: - v3.1 Context Classification 지원

    /// 장소 유형 (home, work, school, custom)
    var placeTypeRaw: String = "custom"

    /// 행정구역: 시/도 (예: 서울특별시, 경기도)
    var administrativeArea: String?

    /// 행정구역: 시/군/구 (예: 강남구, 성남시)
    var locality: String?

    /// 행정구역: 읍/면/동 (예: 역삼동, 분당동)
    var subLocality: String?

    // MARK: - v3.2 H3 헥사곤 그리드 인덱스 (오프라인 Context Classification)

    /// H3 resolution 4 (~1,770 km², 시/도 수준)
    var h3CellRes4: String?

    /// H3 resolution 5 (~253 km², 시/군/구 수준)
    var h3CellRes5: String?

    /// H3 resolution 7 (~5.16 km², 동네 수준)
    var h3CellRes7: String?

    /// H3 resolution 9 (~0.11 km², 건물 수준)
    var h3CellRes9: String?

    /// 장소 유형 (computed)
    var placeType: UserPlaceType {
        get { UserPlaceType(rawValue: placeTypeRaw) ?? .custom }
        set { placeTypeRaw = newValue.rawValue }
    }

    init(
        name: String,
        icon: String,
        latitude: Double,
        longitude: Double,
        address: String,
        isDefault: Bool = false,
        order: Int = 0,
        placeType: UserPlaceType = .custom
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
        self.placeTypeRaw = placeType.rawValue
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

    /// 기본 장소 (집, 회사, 학교) 목록 생성 (v3.1: 회사/학교 분리)
    static func createDefaultPlaces() -> [UserPlace] {
        [
            UserPlace(
                name: "집",
                icon: "🏠",
                latitude: 0,
                longitude: 0,
                address: "",
                isDefault: true,
                order: 0,
                placeType: .home
            ),
            UserPlace(
                name: "회사",
                icon: "🏢",
                latitude: 0,
                longitude: 0,
                address: "",
                isDefault: true,
                order: 1,
                placeType: .work
            ),
            UserPlace(
                name: "학교",
                icon: "🏫",
                latitude: 0,
                longitude: 0,
                address: "",
                isDefault: true,
                order: 2,
                placeType: .school
            )
        ]
    }

    /// 행정구역 정보 설정 (CLPlacemark에서 추출)
    func setAdministrativeArea(from placemark: CLPlacemark) {
        self.administrativeArea = placemark.administrativeArea
        self.locality = placemark.locality
        self.subLocality = placemark.subLocality
    }

    /// 행정구역 정보가 설정되어 있는지 확인
    var hasAdministrativeArea: Bool {
        administrativeArea != nil || locality != nil || subLocality != nil
    }

    /// H3 인덱스가 계산되어 있는지 확인
    var hasH3Indices: Bool {
        h3CellRes7 != nil
    }

    /// H3 셀 인덱스 계산 및 저장 (좌표가 유효할 때 호출)
    /// SwiftyH3로 GPS 좌표를 H3 셀 인덱스로 변환 (오프라인, 순수 수학)
    func computeH3Indices() {
        guard latitude != 0 && longitude != 0 else { return }
        let h3LatLng = CLLocationCoordinate2D(latitude: latitude, longitude: longitude).h3LatLng
        h3CellRes4 = try? h3LatLng.cell(at: .res4).description
        h3CellRes5 = try? h3LatLng.cell(at: .res5).description
        h3CellRes7 = try? h3LatLng.cell(at: .res7).description
        h3CellRes9 = try? h3LatLng.cell(at: .res9).description
    }

    /// 행정구역 문자열 (간략)
    var administrativeAreaSummary: String {
        [administrativeArea, locality, subLocality]
            .compactMap { $0 }
            .joined(separator: " ")
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
