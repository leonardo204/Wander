import Foundation
import Photos
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "MomentScore")

/// 순간의 특별함을 점수화하는 서비스
/// 각 장소/사진의 특별한 정도를 다양한 요소로 평가
/// Wander만의 고유한 "순간 점수" 시스템
class MomentScoreService {

    // MARK: - Moment Score

    struct MomentScore {
        let totalScore: Int             // 종합 점수 (0-100)
        let grade: MomentGrade          // 등급
        let components: ScoreComponents // 세부 점수
        let highlights: [String]        // 하이라이트 포인트
        let specialBadges: [SpecialBadge] // 특별 배지

        /// 별점 (5점 만점)
        var starRating: Double {
            Double(totalScore) / 20.0
        }

        /// UI 표시용
        var displayScore: String {
            "\(totalScore)점"
        }
    }

    // MARK: - Moment Grade

    enum MomentGrade: String, CaseIterable, Codable {
        case legendary      // 전설적인 순간 (90+)
        case epic           // 특별한 순간 (80-89)
        case memorable      // 기억에 남는 순간 (70-79)
        case pleasant       // 즐거운 순간 (60-69)
        case ordinary       // 평범한 순간 (50-59)
        case casual         // 일상적인 순간 (<50)

        var emoji: String {
            switch self {
            case .legendary: return "👑"
            case .epic: return "⭐"
            case .memorable: return "💫"
            case .pleasant: return "😊"
            case .ordinary: return "📍"
            case .casual: return "🚶"
            }
        }

        var koreanName: String {
            switch self {
            case .legendary: return "전설의 순간"
            case .epic: return "특별한 순간"
            case .memorable: return "기억될 순간"
            case .pleasant: return "즐거운 순간"
            case .ordinary: return "평범한 순간"
            case .casual: return "일상의 순간"
            }
        }

        var color: String {
            switch self {
            case .legendary: return "gold"
            case .epic: return "purple"
            case .memorable: return "blue"
            case .pleasant: return "green"
            case .ordinary: return "gray"
            case .casual: return "lightGray"
            }
        }

        static func from(score: Int) -> MomentGrade {
            switch score {
            case 90...100: return .legendary
            case 80..<90: return .epic
            case 70..<80: return .memorable
            case 60..<70: return .pleasant
            case 50..<60: return .ordinary
            default: return .casual
            }
        }
    }

    // MARK: - Score Components

    struct ScoreComponents {
        let timeScore: Int          // 시간 점수 (골든아워 등)
        let placeScore: Int         // 장소 점수 (유명도, 특별함)
        let activityScore: Int      // 활동 점수 (다양성, 독특함)
        let durationScore: Int      // 체류 시간 점수
        let photoScore: Int         // 사진 점수 (수량, 품질)
        let uniquenessScore: Int    // 고유성 점수
    }

    // MARK: - Special Badge

    enum SpecialBadge: String, CaseIterable, Codable {
        case goldenHour         // 골든아워 촬영
        case blueMoment         // 블루모먼트 촬영
        case sunrise            // 일출
        case sunset             // 일몰
        case nightView          // 야경
        case longStay           // 오래 머문 곳
        case photoSpot          // 포토스팟 (사진 많음)
        case hiddenGem          // 숨겨진 보석
        case localFavorite      // 로컬 맛집
        case firstVisit         // 첫 방문
        case milestone          // 마일스톤 (특별 지점)
        case weatherPerfect     // 날씨 최고

        var emoji: String {
            switch self {
            case .goldenHour: return "🌅"
            case .blueMoment: return "🌌"
            case .sunrise: return "☀️"
            case .sunset: return "🌇"
            case .nightView: return "🌃"
            case .longStay: return "⏰"
            case .photoSpot: return "📸"
            case .hiddenGem: return "💎"
            case .localFavorite: return "🏆"
            case .firstVisit: return "🆕"
            case .milestone: return "🏁"
            case .weatherPerfect: return "☀️"
            }
        }

        var koreanName: String {
            switch self {
            case .goldenHour: return "골든아워"
            case .blueMoment: return "블루모먼트"
            case .sunrise: return "일출 순간"
            case .sunset: return "일몰 순간"
            case .nightView: return "야경 명소"
            case .longStay: return "오래 머문 곳"
            case .photoSpot: return "포토스팟"
            case .hiddenGem: return "숨겨진 보석"
            case .localFavorite: return "로컬 인기"
            case .firstVisit: return "첫 방문"
            case .milestone: return "여정의 이정표"
            case .weatherPerfect: return "완벽한 날씨"
            }
        }
    }

    // MARK: - Calculate Score for Place

    /// 장소의 순간 점수 계산
    func calculateScore(
        for cluster: PlaceCluster,
        sceneCategory: VisionAnalysisService.SceneCategory?,
        nearbyHotspots: POIService.NearbyHotspots?,
        allClusters: [PlaceCluster]
    ) -> MomentScore {
        logger.info("⭐ [MomentScore] 점수 계산: \(cluster.name)")

        // 1. 시간 점수 (0-20)
        let timeScore = calculateTimeScore(time: cluster.startTime)

        // 2. 장소 점수 (0-20)
        let placeScore = calculatePlaceScore(
            cluster: cluster,
            sceneCategory: sceneCategory,
            nearbyHotspots: nearbyHotspots
        )

        // 3. 활동 점수 (0-20)
        let activityScore = calculateActivityScore(
            activityType: cluster.activityType,
            sceneCategory: sceneCategory
        )

        // 4. 체류 시간 점수 (0-15)
        let durationScore = calculateDurationScore(cluster: cluster)

        // 5. 사진 점수 (0-15)
        let photoScore = calculatePhotoScore(photoCount: cluster.photos.count)

        // 6. 고유성 점수 (0-10)
        let uniquenessScore = calculateUniquenessScore(
            cluster: cluster,
            allClusters: allClusters
        )

        // 세부 점수
        let components = ScoreComponents(
            timeScore: timeScore,
            placeScore: placeScore,
            activityScore: activityScore,
            durationScore: durationScore,
            photoScore: photoScore,
            uniquenessScore: uniquenessScore
        )

        // 총점 계산
        let totalScore = min(
            timeScore + placeScore + activityScore + durationScore + photoScore + uniquenessScore,
            100
        )

        // 등급 결정
        let grade = MomentGrade.from(score: totalScore)

        // 하이라이트 도출
        let highlights = generateHighlights(components: components, cluster: cluster)

        // 특별 배지 부여
        let badges = awardBadges(
            cluster: cluster,
            components: components,
            sceneCategory: sceneCategory,
            allClusters: allClusters
        )

        let score = MomentScore(
            totalScore: totalScore,
            grade: grade,
            components: components,
            highlights: highlights,
            specialBadges: badges
        )

        logger.info("⭐ [MomentScore] 결과: \(totalScore)점, \(grade.koreanName)")

        return score
    }

    // MARK: - Time Score

    private func calculateTimeScore(time: Date) -> Int {
        let hour = Calendar.current.component(.hour, from: time)

        // 골든아워: 일출 전후 1시간, 일몰 전후 1시간
        // 간단히 6-7시, 17-19시를 골든아워로 가정
        switch hour {
        case 5...7:     // 일출 시간대
            return 20
        case 17...19:   // 일몰 시간대 (골든아워)
            return 20
        case 8...10:    // 오전
            return 15
        case 11...16:   // 한낮
            return 10
        case 20...22:   // 야경 시간
            return 15
        default:        // 새벽/심야
            return 5
        }
    }

    // MARK: - Place Score

    private func calculatePlaceScore(
        cluster: PlaceCluster,
        sceneCategory: VisionAnalysisService.SceneCategory?,
        nearbyHotspots: POIService.NearbyHotspots?
    ) -> Int {
        var score = 10 // 기본 점수

        // 장면 카테고리가 특별한 경우
        if let scene = sceneCategory {
            switch scene {
            case .beach, .mountain, .landmark:
                score += 8
            case .museum, .temple:
                score += 6
            case .park, .nature:
                score += 5
            case .cafe, .restaurant:
                score += 3
            default:
                break
            }
        }

        // 주변에 핫스팟이 많으면 인기 있는 지역
        if let hotspots = nearbyHotspots, !hotspots.isEmpty {
            score += min(hotspots.totalCount, 5)
        }

        return min(score, 20)
    }

    // MARK: - Activity Score

    private func calculateActivityScore(
        activityType: ActivityType,
        sceneCategory: VisionAnalysisService.SceneCategory?
    ) -> Int {
        var score = 10

        // 특별한 활동 유형
        switch activityType {
        case .beach, .mountain:
            score += 8
        case .culture:
            score += 6
        case .tourist:
            score += 5
        case .cafe, .restaurant:
            score += 3
        default:
            break
        }

        // 장면과 활동이 일치하면 보너스
        if let scene = sceneCategory {
            if scene.toActivityType == activityType {
                score += 2
            }
        }

        return min(score, 20)
    }

    // MARK: - Duration Score

    private func calculateDurationScore(cluster: PlaceCluster) -> Int {
        guard let endTime = cluster.endTime else { return 5 }

        let duration = endTime.timeIntervalSince(cluster.startTime)
        let minutes = duration / 60

        switch minutes {
        case 60...:     // 1시간 이상
            return 15
        case 30..<60:   // 30분~1시간
            return 12
        case 15..<30:   // 15~30분
            return 8
        default:        // 15분 미만
            return 5
        }
    }

    // MARK: - Photo Score

    private func calculatePhotoScore(photoCount: Int) -> Int {
        switch photoCount {
        case 20...:     // 20장 이상
            return 15
        case 10..<20:   // 10~19장
            return 12
        case 5..<10:    // 5~9장
            return 8
        case 2..<5:     // 2~4장
            return 5
        default:        // 1장
            return 3
        }
    }

    // MARK: - Uniqueness Score

    private func calculateUniquenessScore(
        cluster: PlaceCluster,
        allClusters: [PlaceCluster]
    ) -> Int {
        // 이 여행에서 유일한 활동 유형이면 보너스
        let sameTypeCount = allClusters.filter { $0.activityType == cluster.activityType }.count

        if sameTypeCount == 1 {
            return 10 // 유일한 유형
        } else if sameTypeCount <= 2 {
            return 7
        } else if sameTypeCount <= 3 {
            return 4
        }

        return 2
    }

    // MARK: - Generate Highlights

    private func generateHighlights(components: ScoreComponents, cluster: PlaceCluster) -> [String] {
        var highlights: [String] = []

        if components.timeScore >= 18 {
            highlights.append("황금 시간대에 방문")
        }

        if components.placeScore >= 15 {
            highlights.append("특별한 장소")
        }

        if components.durationScore >= 12 {
            highlights.append("충분한 시간을 보냄")
        }

        if components.photoScore >= 12 {
            highlights.append("많은 순간을 담음")
        }

        if components.uniquenessScore >= 7 {
            highlights.append("이 여행만의 특별한 경험")
        }

        return highlights
    }

    // MARK: - Award Badges

    private func awardBadges(
        cluster: PlaceCluster,
        components: ScoreComponents,
        sceneCategory: VisionAnalysisService.SceneCategory?,
        allClusters: [PlaceCluster]
    ) -> [SpecialBadge] {
        var badges: [SpecialBadge] = []

        let hour = Calendar.current.component(.hour, from: cluster.startTime)

        // 시간 기반 배지
        if hour >= 5 && hour <= 7 {
            badges.append(.sunrise)
        }
        if hour >= 17 && hour <= 19 {
            badges.append(.goldenHour)
        }
        if hour >= 20 || hour <= 4 {
            badges.append(.nightView)
        }

        // 체류 시간 배지
        if components.durationScore >= 15 {
            badges.append(.longStay)
        }

        // 사진 배지
        if components.photoScore >= 15 {
            badges.append(.photoSpot)
        }

        // 고유성 배지
        if components.uniquenessScore >= 10 {
            badges.append(.hiddenGem)
        }

        // 첫 번째/마지막 장소
        if cluster.id == allClusters.first?.id {
            badges.append(.firstVisit)
        }
        if cluster.id == allClusters.last?.id {
            badges.append(.milestone)
        }

        return badges
    }
}

// MARK: - Trip Overall Score

extension MomentScoreService {
    /// 전체 여행의 종합 점수 계산
    func calculateTripScore(momentScores: [MomentScore]) -> TripOverallScore {
        guard !momentScores.isEmpty else {
            return TripOverallScore(
                averageScore: 0,
                peakMomentScore: 0,
                totalBadges: 0,
                tripGrade: .casual,
                summary: "분석할 순간이 없습니다"
            )
        }

        let scores = momentScores.map { $0.totalScore }
        let averageScore = scores.reduce(0, +) / scores.count
        let peakScore = scores.max() ?? 0
        let totalBadges = momentScores.flatMap { $0.specialBadges }.count

        let tripGrade = MomentGrade.from(score: averageScore)

        let legendaryCount = momentScores.filter { $0.grade == .legendary }.count
        let epicCount = momentScores.filter { $0.grade == .epic }.count

        var summary = "\(momentScores.count)개의 순간 중 "
        if legendaryCount > 0 {
            summary += "전설적인 순간 \(legendaryCount)개"
        } else if epicCount > 0 {
            summary += "특별한 순간 \(epicCount)개"
        } else {
            summary += "평균 \(averageScore)점의 여행"
        }

        return TripOverallScore(
            averageScore: averageScore,
            peakMomentScore: peakScore,
            totalBadges: totalBadges,
            tripGrade: tripGrade,
            summary: summary
        )
    }

    struct TripOverallScore: Codable {
        let averageScore: Int
        let peakMomentScore: Int
        let totalBadges: Int
        let tripGrade: MomentGrade
        let summary: String

        var starRating: Double {
            Double(averageScore) / 20.0
        }
    }
}
