import Foundation
import Photos
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "TravelDNA")

/// 여행 성향 DNA 분석 서비스
/// 사용자의 여행 스타일을 분석하여 고유한 여행 DNA 프로필 생성
/// 경쟁 앱과 차별화되는 Wander만의 핵심 기능
class TravelDNAService {

    // MARK: - Travel DNA Profile

    struct TravelDNA: Codable {
        let primaryType: TravelerType           // 주요 여행자 유형
        let secondaryType: TravelerType?        // 보조 여행자 유형
        let traits: [TravelTrait]               // 여행 특성 (최대 5개)
        let activityBalance: ActivityBalance    // 활동 밸런스
        let paceStyle: PaceStyle                // 여행 페이스
        let timePreference: TimePreference      // 시간대 선호
        let explorationScore: Int               // 탐험 지수 (0-100)
        let socialScore: Int                    // 소셜 지수 (0-100)
        let cultureScore: Int                   // 문화 지수 (0-100)
        let dnaCode: String                     // 고유 DNA 코드 (예: "ADV-NAT-MOR")

        /// UI 표시용 요약
        var summary: String {
            "\(primaryType.emoji) \(primaryType.koreanName)"
        }

        /// 상세 설명
        var description: String {
            primaryType.description
        }
    }

    // MARK: - Traveler Types

    enum TravelerType: String, CaseIterable, Codable {
        case adventurer     // 모험가: 새로운 경험 추구
        case foodie         // 미식가: 맛집 탐방 중심
        case natureLover    // 자연파: 자연 속 힐링
        case culturist      // 문화파: 역사/예술 탐구
        case photographer   // 포토그래퍼: 사진 중심 여행
        case relaxer        // 휴양파: 여유로운 힐링
        case socialite      // 소셜파: 사람들과 함께
        case planner        // 계획파: 체계적인 일정
        case wanderer       // 방랑자: 즉흥적인 여행

        var emoji: String {
            switch self {
            case .adventurer: return "🏔️"
            case .foodie: return "🍜"
            case .natureLover: return "🌿"
            case .culturist: return "🏛️"
            case .photographer: return "📸"
            case .relaxer: return "🌊"
            case .socialite: return "👥"
            case .planner: return "📋"
            case .wanderer: return "🧭"
            }
        }

        var koreanName: String {
            switch self {
            case .adventurer: return "모험가"
            case .foodie: return "미식가"
            case .natureLover: return "자연파"
            case .culturist: return "문화파"
            case .photographer: return "포토그래퍼"
            case .relaxer: return "휴양파"
            case .socialite: return "소셜파"
            case .planner: return "계획파"
            case .wanderer: return "방랑자"
            }
        }

        var description: String {
            switch self {
            case .adventurer:
                return "야외 활동과 자연 탐험 비중이 높은 여행 패턴."
            case .foodie:
                return "음식점/카페 방문 비중이 높은 여행 패턴."
            case .natureLover:
                return "산, 바다, 공원 등 자연 장소 방문이 중심."
            case .culturist:
                return "문화시설, 유적지 방문 비중이 높은 여행 패턴."
            case .photographer:
                return "장소당 평균 사진 수가 많은 여행 패턴."
            case .relaxer:
                return "소수 장소에 오래 체류하는 여행 패턴."
            case .socialite:
                return "식당, 카페 등 소셜 장소 비중이 높은 패턴."
            case .planner:
                return "일정이 빈틈없이 구성된 여행 패턴."
            case .wanderer:
                return "다양한 유형의 장소를 넓게 방문하는 패턴."
            }
        }

        var code: String {
            switch self {
            case .adventurer: return "ADV"
            case .foodie: return "FOD"
            case .natureLover: return "NAT"
            case .culturist: return "CUL"
            case .photographer: return "PHO"
            case .relaxer: return "REL"
            case .socialite: return "SOC"
            case .planner: return "PLN"
            case .wanderer: return "WAN"
            }
        }
    }

    // MARK: - Travel Traits

    enum TravelTrait: String, CaseIterable, Codable {
        case earlyBird          // 아침형
        case nightOwl           // 저녁형
        case spontaneous        // 즉흥적
        case meticulous         // 꼼꼼한
        case budgetConscious    // 가성비
        case luxurySeeking      // 프리미엄
        case localExplorer      // 로컬 탐험
        case touristSpot        // 명소 방문
        case slowTravel         // 느린 여행
        case fastPaced          // 빠른 일정
        case photoEnthusiast    // 사진 매니아
        case memoryMaker        // 추억 제조기

        var emoji: String {
            switch self {
            case .earlyBird: return "🌅"
            case .nightOwl: return "🌙"
            case .spontaneous: return "✨"
            case .meticulous: return "📝"
            case .budgetConscious: return "💰"
            case .luxurySeeking: return "💎"
            case .localExplorer: return "🗺️"
            case .touristSpot: return "📍"
            case .slowTravel: return "🐢"
            case .fastPaced: return "🚀"
            case .photoEnthusiast: return "📷"
            case .memoryMaker: return "💝"
            }
        }

        var koreanName: String {
            switch self {
            case .earlyBird: return "아침형"
            case .nightOwl: return "저녁형"
            case .spontaneous: return "즉흥파"
            case .meticulous: return "꼼꼼이"
            case .budgetConscious: return "가성비파"
            case .luxurySeeking: return "프리미엄"
            case .localExplorer: return "로컬 탐험가"
            case .touristSpot: return "명소 수집가"
            case .slowTravel: return "슬로우 트래블러"
            case .fastPaced: return "스피드러너"
            case .photoEnthusiast: return "사진 매니아"
            case .memoryMaker: return "추억 제조기"
            }
        }
    }

    // MARK: - Activity Balance

    struct ActivityBalance: Codable {
        let outdoor: Int        // 야외 활동 (0-100)
        let indoor: Int         // 실내 활동 (0-100)
        let active: Int         // 활동적 (0-100)
        let relaxing: Int       // 휴식 (0-100)

        var dominantStyle: String {
            if outdoor > indoor && active > relaxing {
                return "액티브 아웃도어"
            } else if outdoor > indoor && relaxing > active {
                return "자연 속 힐링"
            } else if indoor > outdoor && active > relaxing {
                return "도시 탐험가"
            } else {
                return "실내 휴식파"
            }
        }
    }

    // MARK: - Pace Style

    enum PaceStyle: String, Codable {
        case ultraSlow      // 한 곳에서 오래
        case slow           // 여유로운 페이스
        case moderate       // 적당한 페이스
        case fast           // 빠른 페이스
        case ultraFast      // 최대한 많이

        var koreanName: String {
            switch self {
            case .ultraSlow: return "깊이 있는 여행"
            case .slow: return "여유로운 페이스"
            case .moderate: return "균형 잡힌 페이스"
            case .fast: return "알찬 일정"
            case .ultraFast: return "풀코스 여행"
            }
        }

        var placesPerDay: String {
            switch self {
            case .ultraSlow: return "1-2곳/일"
            case .slow: return "2-3곳/일"
            case .moderate: return "3-5곳/일"
            case .fast: return "5-7곳/일"
            case .ultraFast: return "7곳 이상/일"
            }
        }
    }

    // MARK: - Time Preference

    struct TimePreference: Codable {
        let morningActivity: Int    // 아침 활동량 (0-100)
        let afternoonActivity: Int  // 오후 활동량 (0-100)
        let eveningActivity: Int    // 저녁 활동량 (0-100)

        var peakTime: String {
            if morningActivity >= afternoonActivity && morningActivity >= eveningActivity {
                return "오전"
            } else if afternoonActivity >= eveningActivity {
                return "오후"
            } else {
                return "저녁"
            }
        }

        var pattern: String {
            if morningActivity > 60 && eveningActivity < 40 {
                return "아침형 여행자"
            } else if eveningActivity > 60 && morningActivity < 40 {
                return "저녁형 여행자"
            } else {
                return "균형형 여행자"
            }
        }
    }

    // MARK: - Analyze Travel DNA

    /// 여행 기록에서 DNA 분석
    /// - Parameter clusters: 분석할 장소 클러스터들
    /// - Returns: 여행 DNA 프로필
    func analyzeDNA(from clusters: [PlaceCluster], sceneCategories: [VisionAnalysisService.SceneCategory?]) -> TravelDNA {
        logger.info("🧬 [TravelDNA] 분석 시작 - \(clusters.count)개 장소")

        // 1. 활동 유형 분석
        let activityCounts = analyzeActivityTypes(clusters: clusters, scenes: sceneCategories)

        // 2. 시간대 분석
        let timePreference = analyzeTimePreference(clusters: clusters)

        // 3. 페이스 분석
        let paceStyle = analyzePaceStyle(clusters: clusters)

        // 4. 활동 밸런스 분석
        let activityBalance = analyzeActivityBalance(clusters: clusters, scenes: sceneCategories)

        // 5. 여행자 유형 결정
        let (primaryType, secondaryType) = determineTravelerType(
            activityCounts: activityCounts,
            timePreference: timePreference,
            paceStyle: paceStyle
        )

        // 6. 특성 도출
        let traits = deriveTraits(
            timePreference: timePreference,
            paceStyle: paceStyle,
            activityBalance: activityBalance,
            clusters: clusters
        )

        // 7. 점수 계산
        let explorationScore = calculateExplorationScore(clusters: clusters)
        let socialScore = calculateSocialScore(clusters: clusters, scenes: sceneCategories)
        let cultureScore = calculateCultureScore(activityCounts: activityCounts)

        // 8. DNA 코드 생성
        let dnaCode = generateDNACode(
            primary: primaryType,
            secondary: secondaryType,
            topTrait: traits.first
        )

        let dna = TravelDNA(
            primaryType: primaryType,
            secondaryType: secondaryType,
            traits: traits,
            activityBalance: activityBalance,
            paceStyle: paceStyle,
            timePreference: timePreference,
            explorationScore: explorationScore,
            socialScore: socialScore,
            cultureScore: cultureScore,
            dnaCode: dnaCode
        )

        logger.info("🧬 [TravelDNA] 분석 완료 - \(dna.summary), 코드: \(dnaCode)")

        return dna
    }

    // MARK: - Analysis Methods

    private func analyzeActivityTypes(
        clusters: [PlaceCluster],
        scenes: [VisionAnalysisService.SceneCategory?]
    ) -> [ActivityType: Int] {
        var counts: [ActivityType: Int] = [:]

        for cluster in clusters {
            counts[cluster.activityType, default: 0] += 1
        }

        // 장면 분류 결과도 반영
        for scene in scenes.compactMap({ $0 }) {
            let activity = scene.toActivityType
            counts[activity, default: 0] += 1
        }

        return counts
    }

    private func analyzeTimePreference(clusters: [PlaceCluster]) -> TimePreference {
        var morning = 0
        var afternoon = 0
        var evening = 0

        for cluster in clusters {
            let hour = Calendar.current.component(.hour, from: cluster.startTime)

            if hour >= 6 && hour < 12 {
                morning += cluster.photos.count
            } else if hour >= 12 && hour < 18 {
                afternoon += cluster.photos.count
            } else {
                evening += cluster.photos.count
            }
        }

        let total = max(morning + afternoon + evening, 1)

        return TimePreference(
            morningActivity: morning * 100 / total,
            afternoonActivity: afternoon * 100 / total,
            eveningActivity: evening * 100 / total
        )
    }

    private func analyzePaceStyle(clusters: [PlaceCluster]) -> PaceStyle {
        guard !clusters.isEmpty else { return .moderate }

        // 일별 장소 수 계산
        let calendar = Calendar.current
        var placesByDay: [Date: Int] = [:]

        for cluster in clusters {
            let day = calendar.startOfDay(for: cluster.startTime)
            placesByDay[day, default: 0] += 1
        }

        let avgPlacesPerDay = Double(clusters.count) / Double(max(placesByDay.count, 1))

        switch avgPlacesPerDay {
        case 0..<2: return .ultraSlow
        case 2..<3: return .slow
        case 3..<5: return .moderate
        case 5..<7: return .fast
        default: return .ultraFast
        }
    }

    private func analyzeActivityBalance(
        clusters: [PlaceCluster],
        scenes: [VisionAnalysisService.SceneCategory?]
    ) -> ActivityBalance {
        var outdoor = 0
        var indoor = 0
        var active = 0
        var relaxing = 0

        let outdoorTypes: Set<ActivityType> = [.beach, .mountain, .tourist]
        let indoorTypes: Set<ActivityType> = [.cafe, .restaurant, .culture, .shopping]
        let activeTypes: Set<ActivityType> = [.mountain, .tourist, .shopping]
        let relaxingTypes: Set<ActivityType> = [.cafe, .beach, .restaurant]

        for cluster in clusters {
            if outdoorTypes.contains(cluster.activityType) {
                outdoor += 1
            }
            if indoorTypes.contains(cluster.activityType) {
                indoor += 1
            }
            if activeTypes.contains(cluster.activityType) {
                active += 1
            }
            if relaxingTypes.contains(cluster.activityType) {
                relaxing += 1
            }
        }

        let total = max(clusters.count, 1)

        return ActivityBalance(
            outdoor: outdoor * 100 / total,
            indoor: indoor * 100 / total,
            active: active * 100 / total,
            relaxing: relaxing * 100 / total
        )
    }

    private func determineTravelerType(
        activityCounts: [ActivityType: Int],
        timePreference: TimePreference,
        paceStyle: PaceStyle
    ) -> (TravelerType, TravelerType?) {
        // 활동 유형별 점수
        var typeScores: [TravelerType: Int] = [:]

        for (activity, count) in activityCounts {
            switch activity {
            case .mountain, .beach:
                typeScores[.natureLover, default: 0] += count * 2
                typeScores[.adventurer, default: 0] += count
            case .restaurant, .cafe:
                typeScores[.foodie, default: 0] += count * 2
                typeScores[.relaxer, default: 0] += count
            case .culture:
                typeScores[.culturist, default: 0] += count * 2
            case .tourist:
                typeScores[.photographer, default: 0] += count
                typeScores[.wanderer, default: 0] += count
            case .shopping:
                typeScores[.socialite, default: 0] += count
            default:
                typeScores[.wanderer, default: 0] += count
            }
        }

        // 페이스 반영
        switch paceStyle {
        case .ultraSlow, .slow:
            typeScores[.relaxer, default: 0] += 3
        case .fast, .ultraFast:
            typeScores[.planner, default: 0] += 3
            typeScores[.adventurer, default: 0] += 2
        default:
            break
        }

        // 시간대 반영
        if timePreference.morningActivity > 60 {
            typeScores[.planner, default: 0] += 2
        }
        if timePreference.eveningActivity > 60 {
            typeScores[.socialite, default: 0] += 2
        }

        // 정렬하여 1, 2위 선택
        let sorted = typeScores.sorted { $0.value > $1.value }

        let primary = sorted.first?.key ?? .wanderer
        let secondary = sorted.count > 1 ? sorted[1].key : nil

        return (primary, secondary)
    }

    private func deriveTraits(
        timePreference: TimePreference,
        paceStyle: PaceStyle,
        activityBalance: ActivityBalance,
        clusters: [PlaceCluster]
    ) -> [TravelTrait] {
        var traits: [TravelTrait] = []

        // 시간대 특성
        if timePreference.morningActivity > 60 {
            traits.append(.earlyBird)
        } else if timePreference.eveningActivity > 60 {
            traits.append(.nightOwl)
        }

        // 페이스 특성
        switch paceStyle {
        case .ultraSlow, .slow:
            traits.append(.slowTravel)
        case .fast, .ultraFast:
            traits.append(.fastPaced)
        default:
            break
        }

        // 활동 밸런스 특성
        if activityBalance.outdoor > 60 {
            traits.append(.localExplorer)
        }

        // 사진 특성
        let avgPhotosPerPlace = clusters.isEmpty ? 0 : clusters.map { $0.photos.count }.reduce(0, +) / clusters.count
        if avgPhotosPerPlace > 10 {
            traits.append(.photoEnthusiast)
        }

        // 추억 제조기 (다양한 장소 방문)
        if clusters.count >= 5 {
            traits.append(.memoryMaker)
        }

        return Array(traits.prefix(5))
    }

    private func calculateExplorationScore(clusters: [PlaceCluster]) -> Int {
        // 다양성 + 이동 거리 기반
        let uniqueActivities = Set(clusters.map { $0.activityType }).count
        let placeCount = clusters.count

        let diversityScore = min(uniqueActivities * 15, 50)
        let quantityScore = min(placeCount * 5, 50)

        return diversityScore + quantityScore
    }

    private func calculateSocialScore(clusters: [PlaceCluster], scenes: [VisionAnalysisService.SceneCategory?]) -> Int {
        var score = 50 // 기본값

        // 사람 관련 장면이 있으면 +
        for scene in scenes.compactMap({ $0 }) {
            if scene == .people {
                score += 10
            }
        }

        // 소셜 장소 방문
        for cluster in clusters {
            if cluster.activityType == .restaurant || cluster.activityType == .cafe {
                score += 5
            }
        }

        return min(score, 100)
    }

    private func calculateCultureScore(activityCounts: [ActivityType: Int]) -> Int {
        var score = 30 // 기본값

        if let cultureCount = activityCounts[.culture] {
            score += cultureCount * 20
        }

        if let touristCount = activityCounts[.tourist] {
            score += touristCount * 10
        }

        return min(score, 100)
    }

    private func generateDNACode(
        primary: TravelerType,
        secondary: TravelerType?,
        topTrait: TravelTrait?
    ) -> String {
        var code = primary.code

        if let secondary = secondary {
            code += "-\(secondary.code)"
        }

        if let trait = topTrait {
            let traitCode: String
            switch trait {
            case .earlyBird: traitCode = "MOR"
            case .nightOwl: traitCode = "NIT"
            case .slowTravel: traitCode = "SLO"
            case .fastPaced: traitCode = "FST"
            case .photoEnthusiast: traitCode = "PHT"
            default: traitCode = "STD"
            }
            code += "-\(traitCode)"
        }

        return code
    }
}
