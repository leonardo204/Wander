import Foundation
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "SmartTitle")

/// 분석 결과 기반 스마트 제목 생성기
/// "서초동 1714-25 여행" 대신 더 의미있는 제목 생성
class SmartTitleGenerator {

    // MARK: - Title Generation Context

    struct TitleContext {
        let places: [PlaceInfo]
        let startDate: Date
        let endDate: Date
        let totalDistance: Double  // km
        let photoCount: Int
        let dominantSceneCategory: VisionAnalysisService.SceneCategory?
        let analysisLevel: VisionAnalysisService.AnalysisLevel

        struct PlaceInfo {
            let name: String
            let locality: String?      // 시/군/구
            let subLocality: String?   // 동/읍/면
            let sceneCategory: VisionAnalysisService.SceneCategory?
            let activityType: ActivityType
            let photoCount: Int
        }
    }

    // MARK: - Generate Smart Title

    /// 스마트 제목 생성
    /// - Parameter context: 분석 컨텍스트
    /// - Returns: 생성된 제목
    func generateTitle(from context: TitleContext) -> String {
        logger.info("📝 [Title] 스마트 제목 생성 시작")

        // 1. 여행 유형 판단
        let tripType = determineTripType(context: context)
        logger.info("📝 [Title] 여행 유형: \(tripType.rawValue)")

        // 2. 대표 장소 선정
        let representativePlace = selectRepresentativePlace(from: context.places)
        logger.info("📝 [Title] 대표 장소: \(representativePlace ?? "없음")")

        // 3. 지역명 추출
        let regionName = extractRegionName(from: context.places)
        logger.info("📝 [Title] 지역명: \(regionName ?? "없음")")

        // 4. 활동 키워드 추출
        let activityKeyword = extractActivityKeyword(from: context)
        logger.info("📝 [Title] 활동 키워드: \(activityKeyword ?? "없음")")

        // 5. 제목 조합
        let title = composeTitle(
            tripType: tripType,
            representativePlace: representativePlace,
            regionName: regionName,
            activityKeyword: activityKeyword,
            context: context
        )

        logger.info("📝 [Title] 최종 제목: \(title)")
        return title
    }

    // MARK: - Trip Type

    enum TripType: String {
        case dayTrip         // 당일치기
        case weekend         // 주말 여행
        case longTrip        // 장기 여행
        case cityTour        // 도시 투어
        case natureTour      // 자연 투어
        case foodTour        // 맛집 투어
        case cultureTour     // 문화 투어
        case dailyRecord     // 일상 기록

        var prefix: String {
            switch self {
            case .dayTrip: return ""
            case .weekend: return "주말"
            case .longTrip: return ""
            case .cityTour: return ""
            case .natureTour: return ""
            case .foodTour: return ""
            case .cultureTour: return ""
            case .dailyRecord: return ""
            }
        }

        var suffix: String {
            switch self {
            case .dayTrip: return "나들이"
            case .weekend: return "여행"
            case .longTrip: return "여행"
            case .cityTour: return "투어"
            case .natureTour: return "힐링"
            case .foodTour: return "맛집 탐방"
            case .cultureTour: return "문화 탐방"
            case .dailyRecord: return "일상"
            }
        }
    }

    /// 여행 유형 판단
    private func determineTripType(context: TitleContext) -> TripType {
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: context.startDate, to: context.endDate).day ?? 0

        // 기간 기반 판단
        if daysBetween == 0 {
            // 같은 날
            if context.totalDistance < 5 {
                return .dailyRecord
            }
            return .dayTrip
        } else if daysBetween <= 2 {
            return .weekend
        }

        // 활동 기반 판단
        let activityCounts = Dictionary(grouping: context.places, by: { $0.activityType })

        if let mostFrequent = activityCounts.max(by: { $0.value.count < $1.value.count })?.key {
            switch mostFrequent {
            case .restaurant, .cafe:
                return .foodTour
            case .culture:
                return .cultureTour
            case .mountain, .beach:
                return .natureTour
            case .tourist, .shopping:
                return .cityTour
            default:
                break
            }
        }

        // 장면 기반 판단 (iOS 17+)
        if let scene = context.dominantSceneCategory {
            switch scene {
            case .food, .cafe, .restaurant:
                return .foodTour
            case .museum, .temple, .landmark:
                return .cultureTour
            case .mountain, .beach, .nature, .park:
                return .natureTour
            case .city, .shopping:
                return .cityTour
            default:
                break
            }
        }

        return daysBetween >= 3 ? .longTrip : .weekend
    }

    // MARK: - Representative Place

    /// 대표 장소 선정 (사진이 가장 많은 장소)
    private func selectRepresentativePlace(from places: [TitleContext.PlaceInfo]) -> String? {
        guard !places.isEmpty else { return nil }

        // 1. 사진 수가 가장 많은 장소
        if let topPlace = places.max(by: { $0.photoCount < $1.photoCount }) {
            // 주소가 아닌 의미있는 이름인 경우만
            if !isAddressLikeName(topPlace.name) {
                return topPlace.name
            }
        }

        // 2. 장면 카테고리가 명확한 장소
        for place in places {
            if let scene = place.sceneCategory,
               scene != .unknown && scene != .city {
                return scene.koreanName
            }
        }

        return nil
    }

    /// 주소 형태의 이름인지 확인
    private func isAddressLikeName(_ name: String) -> Bool {
        // 숫자로 끝나거나 "동", "로", "길" 등으로 끝나는 경우
        let addressPatterns = [
            "\\d+$",                    // 숫자로 끝남
            "\\d+-\\d+$",               // 번지 형태
            "(동|로|길|리)\\s*\\d*$",   // 동/로/길 + 숫자
        ]

        for pattern in addressPatterns {
            if name.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Region Name

    /// 지역명 추출 (시/군/구 또는 동/읍/면)
    private func extractRegionName(from places: [TitleContext.PlaceInfo]) -> String? {
        // locality (시/군/구) 빈도 계산
        var localityCounts: [String: Int] = [:]

        for place in places {
            if let locality = place.locality {
                localityCounts[locality, default: 0] += 1
            }
        }

        // 가장 빈도 높은 지역
        if let topLocality = localityCounts.max(by: { $0.value < $1.value })?.key {
            // 긴 지역명은 축약
            return abbreviateRegionName(topLocality)
        }

        // subLocality로 대체
        for place in places {
            if let subLocality = place.subLocality {
                return subLocality
            }
        }

        return nil
    }

    /// 지역명 축약
    private func abbreviateRegionName(_ name: String) -> String {
        // "서울특별시" → "서울"
        // "경기도 성남시" → "성남"
        let abbreviations: [String: String] = [
            "서울특별시": "서울",
            "부산광역시": "부산",
            "대구광역시": "대구",
            "인천광역시": "인천",
            "광주광역시": "광주",
            "대전광역시": "대전",
            "울산광역시": "울산",
            "세종특별자치시": "세종",
            "제주특별자치도": "제주",
        ]

        if let abbreviated = abbreviations[name] {
            return abbreviated
        }

        // "XX시", "XX군" 형태에서 뒤 글자 제거
        if name.hasSuffix("시") || name.hasSuffix("군") || name.hasSuffix("구") {
            return String(name.dropLast())
        }

        return name
    }

    // MARK: - Activity Keyword

    /// 활동 키워드 추출
    private func extractActivityKeyword(from context: TitleContext) -> String? {
        // 장면 카테고리 기반
        if let scene = context.dominantSceneCategory {
            switch scene {
            case .beach: return "바다"
            case .mountain: return "산"
            case .cafe: return "카페"
            case .food: return "맛집"
            case .temple: return "사찰"
            case .museum: return "박물관"
            case .park: return "공원"
            default: break
            }
        }

        // 활동 타입 기반
        let activityCounts = Dictionary(grouping: context.places, by: { $0.activityType })
        if let dominant = activityCounts.max(by: { $0.value.count < $1.value.count })?.key {
            switch dominant {
            case .beach: return "바다"
            case .mountain: return "산"
            case .cafe: return "카페"
            case .restaurant: return "맛집"
            case .culture: return "문화"
            case .shopping: return "쇼핑"
            default: break
            }
        }

        return nil
    }

    // MARK: - Title Composition

    /// 최종 제목 조합
    private func composeTitle(
        tripType: TripType,
        representativePlace: String?,
        regionName: String?,
        activityKeyword: String?,
        context: TitleContext
    ) -> String {
        // 패턴 1: "[지역] [활동] [여행유형]" - 예: "강릉 바다 힐링"
        if let region = regionName, let activity = activityKeyword {
            let suffix = tripType.suffix
            if !suffix.isEmpty {
                return "\(region) \(activity) \(suffix)"
            }
            return "\(region) \(activity)"
        }

        // 패턴 2: "[대표장소] [여행유형]" - 예: "경복궁 문화 탐방"
        if let place = representativePlace {
            let suffix = tripType.suffix
            return "\(place) \(suffix)"
        }

        // 패턴 3: "[지역] [여행유형]" - 예: "제주 주말 여행"
        if let region = regionName {
            let prefix = tripType.prefix
            let suffix = tripType.suffix
            if !prefix.isEmpty {
                return "\(region) \(prefix) \(suffix)"
            }
            return "\(region) \(suffix)"
        }

        // 패턴 4: 날짜 기반 (폴백)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        if Calendar.current.isDate(context.startDate, inSameDayAs: context.endDate) {
            formatter.dateFormat = "M월 d일"
            return "\(formatter.string(from: context.startDate)) \(tripType.suffix)"
        } else {
            formatter.dateFormat = "M월"
            return "\(formatter.string(from: context.startDate)) \(tripType.suffix)"
        }
    }

    // MARK: - Subtitle Generation

    /// 서브타이틀 생성 (요약 정보)
    func generateSubtitle(from context: TitleContext) -> String {
        var parts: [String] = []

        // 날짜 정보
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        if Calendar.current.isDate(context.startDate, inSameDayAs: context.endDate) {
            formatter.dateFormat = "M월 d일 (E)"
            parts.append(formatter.string(from: context.startDate))
        } else {
            formatter.dateFormat = "M.d"
            let start = formatter.string(from: context.startDate)
            let end = formatter.string(from: context.endDate)
            parts.append("\(start) ~ \(end)")
        }

        // 장소 수
        if context.places.count > 1 {
            parts.append("\(context.places.count)곳")
        }

        // 거리
        if context.totalDistance >= 1 {
            parts.append(String(format: "%.1fkm", context.totalDistance))
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - Title Templates (iOS 18+ 고급 기능용)

extension SmartTitleGenerator {

    /// iOS 18+ 전용: 더 창의적인 제목 생성
    @available(iOS 18.0, *)
    func generateCreativeTitle(from context: TitleContext) -> String {
        // TODO: FastVLM 등 iOS 18+ 기능 활용 시 더 창의적인 제목 생성 가능
        // 현재는 기본 생성기와 동일하게 동작
        return generateTitle(from: context)
    }

    /// 제목 템플릿 (다양한 스타일)
    enum TitleStyle {
        case descriptive    // 설명적: "강릉 바다 힐링"
        case emotional      // 감성적: "푸른 바다와 함께한 하루"
        case minimal        // 미니멀: "강릉"
        case dated          // 날짜 중심: "2024년 여름 강릉"
    }

    func generateTitle(from context: TitleContext, style: TitleStyle) -> String {
        switch style {
        case .descriptive:
            return generateTitle(from: context)
        case .emotional:
            return generateEmotionalTitle(from: context)
        case .minimal:
            return extractRegionName(from: context.places) ?? generateTitle(from: context)
        case .dated:
            return generateDatedTitle(from: context)
        }
    }

    private func generateEmotionalTitle(from context: TitleContext) -> String {
        // 장면 기반 감성적 표현
        if let scene = context.dominantSceneCategory {
            switch scene {
            case .beach: return "푸른 바다와 함께"
            case .mountain: return "산의 품에서"
            case .cafe: return "향기로운 여유"
            case .food: return "맛있는 하루"
            case .nature: return "자연 속 힐링"
            case .city: return "도시의 하루"
            default: break
            }
        }

        return generateTitle(from: context)
    }

    private func generateDatedTitle(from context: TitleContext) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        let calendar = Calendar.current
        let year = calendar.component(.year, from: context.startDate)
        let month = calendar.component(.month, from: context.startDate)

        // 계절 판단
        let season: String
        switch month {
        case 3...5: season = "봄"
        case 6...8: season = "여름"
        case 9...11: season = "가을"
        default: season = "겨울"
        }

        if let region = extractRegionName(from: context.places) {
            return "\(year)년 \(season) \(region)"
        }

        return "\(year)년 \(season) 여행"
    }
}
