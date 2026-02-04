import Foundation
import MapKit
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "POIService")

/// MKLocalSearch 기반 주변 POI(관심지점) 검색 서비스
/// 좌표 주변의 카페, 식당, 관광지 등을 검색
@MainActor
class POIService {

    // MARK: - POI Result

    struct POIResult: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let category: POICategory
        let coordinate: CLLocationCoordinate2D
        let distance: Double  // 미터 단위
        let address: String?
        let phoneNumber: String?
        let url: URL?

        // Hashable 구현
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: POIResult, rhs: POIResult) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - POI Category

    enum POICategory: String, CaseIterable {
        case cafe
        case restaurant
        case attraction      // 관광 명소
        case museum
        case park
        case shopping
        case hotel
        case entertainment   // 엔터테인먼트
        case transportation  // 교통
        case other

        var emoji: String {
            switch self {
            case .cafe: return "☕"
            case .restaurant: return "🍽️"
            case .attraction: return "📸"
            case .museum: return "🏛️"
            case .park: return "🌳"
            case .shopping: return "🛍️"
            case .hotel: return "🏨"
            case .entertainment: return "🎭"
            case .transportation: return "🚉"
            case .other: return "📍"
            }
        }

        var koreanName: String {
            switch self {
            case .cafe: return "카페"
            case .restaurant: return "맛집"
            case .attraction: return "명소"
            case .museum: return "박물관"
            case .park: return "공원"
            case .shopping: return "쇼핑"
            case .hotel: return "숙소"
            case .entertainment: return "즐길거리"
            case .transportation: return "교통"
            case .other: return "기타"
            }
        }

        /// MKPointOfInterestCategory로 변환
        var mkCategories: [MKPointOfInterestCategory] {
            switch self {
            case .cafe:
                return [.cafe]
            case .restaurant:
                return [.restaurant, .bakery, .foodMarket]
            case .attraction:
                return [.nationalPark, .beach, .amusementPark]
            case .museum:
                return [.museum, .theater]
            case .park:
                return [.park, .nationalPark]
            case .shopping:
                return [.store]
            case .hotel:
                return [.hotel]
            case .entertainment:
                return [.nightlife, .theater, .movieTheater]
            case .transportation:
                return [.airport, .publicTransport]
            case .other:
                return []
            }
        }
    }

    // MARK: - Search Configuration

    struct SearchConfig {
        var radius: Double = 500        // 검색 반경 (미터)
        var maxResults: Int = 5         // 최대 결과 수
        var categories: [POICategory]   // 검색할 카테고리

        static let nearbyHotspots = SearchConfig(
            radius: 500,
            maxResults: 10,
            categories: [.cafe, .restaurant, .attraction, .museum]
        )

        static let allCategories = SearchConfig(
            radius: 300,
            maxResults: 5,
            categories: POICategory.allCases
        )
    }

    // MARK: - Search Methods

    /// 특정 좌표 주변의 POI 검색
    /// - Parameters:
    ///   - coordinate: 검색 중심 좌표
    ///   - config: 검색 설정
    /// - Returns: 카테고리별로 그룹화된 POI 목록
    func searchNearbyPOIs(
        coordinate: CLLocationCoordinate2D,
        config: SearchConfig = .nearbyHotspots
    ) async -> [POICategory: [POIResult]] {
        logger.info("🗺️ [POI] 주변 검색 시작: (\(coordinate.latitude), \(coordinate.longitude)), 반경: \(config.radius)m")

        var results: [POICategory: [POIResult]] = [:]

        for category in config.categories {
            let pois = await searchPOIs(
                coordinate: coordinate,
                category: category,
                radius: config.radius,
                maxResults: config.maxResults
            )

            if !pois.isEmpty {
                results[category] = pois
                logger.info("🗺️ [POI] \(category.koreanName): \(pois.count)개 발견")
            }
        }

        logger.info("🗺️ [POI] 검색 완료 - 총 \(results.values.flatMap { $0 }.count)개 POI")
        return results
    }

    /// 특정 카테고리의 POI 검색
    private func searchPOIs(
        coordinate: CLLocationCoordinate2D,
        category: POICategory,
        radius: Double,
        maxResults: Int
    ) async -> [POIResult] {
        // 카테고리별 검색어 설정
        let searchQuery = getSearchQuery(for: category)

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery

        // 검색 영역 설정
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.region = region

        // POI 필터 설정 (iOS 13+)
        if !category.mkCategories.isEmpty {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: category.mkCategories)
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            let pois = response.mapItems
                .prefix(maxResults)
                .map { item -> POIResult in
                    let itemLocation = CLLocation(
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude
                    )
                    let distance = centerLocation.distance(from: itemLocation)

                    return POIResult(
                        name: item.name ?? "알 수 없는 장소",
                        category: category,
                        coordinate: item.placemark.coordinate,
                        distance: distance,
                        address: formatAddress(from: item.placemark),
                        phoneNumber: item.phoneNumber,
                        url: item.url
                    )
                }
                .filter { $0.distance <= radius }  // 반경 내 필터링
                .sorted { $0.distance < $1.distance }  // 거리순 정렬

            return Array(pois)
        } catch {
            logger.warning("🗺️ [POI] 검색 실패 (\(category.koreanName)): \(error.localizedDescription)")
            return []
        }
    }

    /// 장소 이름으로 POI 검색 (특정 장소명 검색)
    func searchByName(
        query: String,
        coordinate: CLLocationCoordinate2D,
        radius: Double = 1000
    ) async -> [POIResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            return response.mapItems.map { item in
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = centerLocation.distance(from: itemLocation)

                return POIResult(
                    name: item.name ?? query,
                    category: categorize(mapItem: item),
                    coordinate: item.placemark.coordinate,
                    distance: distance,
                    address: formatAddress(from: item.placemark),
                    phoneNumber: item.phoneNumber,
                    url: item.url
                )
            }
        } catch {
            logger.warning("🗺️ [POI] 이름 검색 실패 (\(query)): \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - POI-based Place Name Enhancement

    /// 주소 대신 더 의미있는 장소명 찾기
    /// 주변 유명 POI를 검색하여 "OO 근처" 형태로 반환
    func findBetterPlaceName(
        coordinate: CLLocationCoordinate2D,
        currentName: String
    ) async -> String? {
        // 주변 명소 검색
        let landmarks = await searchPOIs(
            coordinate: coordinate,
            category: .attraction,
            radius: 200,
            maxResults: 3
        )

        // 주변 유명 장소가 있으면 활용
        if let nearestLandmark = landmarks.first {
            // 50m 이내면 해당 장소명 사용
            if nearestLandmark.distance < 50 {
                return nearestLandmark.name
            }
            // 200m 이내면 "근처" 형태
            if nearestLandmark.distance < 200 {
                return "\(nearestLandmark.name) 근처"
            }
        }

        return nil
    }

    // MARK: - Helper Methods

    /// 카테고리별 검색어
    private func getSearchQuery(for category: POICategory) -> String {
        switch category {
        case .cafe: return "카페"
        case .restaurant: return "맛집"
        case .attraction: return "관광명소"
        case .museum: return "박물관"
        case .park: return "공원"
        case .shopping: return "쇼핑"
        case .hotel: return "호텔"
        case .entertainment: return "놀거리"
        case .transportation: return "역"
        case .other: return ""
        }
    }

    /// MKMapItem을 POICategory로 분류
    private func categorize(mapItem: MKMapItem) -> POICategory {
        if let category = mapItem.pointOfInterestCategory {
            switch category {
            case .cafe:
                return .cafe
            case .restaurant, .bakery, .foodMarket:
                return .restaurant
            case .museum, .theater:
                return .museum
            case .park, .nationalPark:
                return .park
            case .store:
                return .shopping
            case .hotel:
                return .hotel
            case .nightlife, .movieTheater:
                return .entertainment
            case .airport, .publicTransport:
                return .transportation
            default:
                return .other
            }
        }
        return .other
    }

    /// Placemark에서 간략 주소 포맷
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        var components: [String] = []

        if let locality = placemark.locality {
            components.append(locality)
        }
        if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }

        return components.isEmpty ? nil : components.joined(separator: " ")
    }
}

// MARK: - Nearby Hotspots Result

extension POIService {
    /// 클러스터 주변의 핫스팟 정보
    struct NearbyHotspots {
        let cafes: [POIResult]
        let restaurants: [POIResult]
        let attractions: [POIResult]

        var isEmpty: Bool {
            cafes.isEmpty && restaurants.isEmpty && attractions.isEmpty
        }

        var totalCount: Int {
            cafes.count + restaurants.count + attractions.count
        }

        /// UI 표시용 요약
        var summary: String {
            var parts: [String] = []
            if !cafes.isEmpty { parts.append("카페 \(cafes.count)") }
            if !restaurants.isEmpty { parts.append("맛집 \(restaurants.count)") }
            if !attractions.isEmpty { parts.append("명소 \(attractions.count)") }
            return parts.joined(separator: " · ")
        }
    }

    /// 클러스터 주변 핫스팟 검색 (간편 메서드)
    func findNearbyHotspots(coordinate: CLLocationCoordinate2D) async -> NearbyHotspots {
        let results = await searchNearbyPOIs(coordinate: coordinate, config: .nearbyHotspots)

        return NearbyHotspots(
            cafes: results[.cafe] ?? [],
            restaurants: results[.restaurant] ?? [],
            attractions: results[.attraction] ?? []
        )
    }
}
