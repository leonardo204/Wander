import Foundation
import Photos
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "InsightEngine")

/// 숨겨진 인사이트 발굴 엔진
/// 여행 데이터에서 사용자가 미처 인식하지 못한 패턴과 발견을 찾아냄
/// Wander만의 차별화된 "발견의 즐거움" 제공
class InsightEngine {

    // MARK: - Insight Types

    /// 발견된 인사이트
    struct TravelInsight: Codable {
        let id: UUID
        let type: InsightType
        let title: String
        let description: String
        let emoji: String
        let importance: InsightImportance
        // relatedData는 Codable이 아닌 타입 포함으로 제외
        let actionSuggestion: String?

        // 내부에서만 사용하는 non-Codable 필드 (JSON 저장 시 제외)
        var relatedData: InsightData?

        enum CodingKeys: String, CodingKey {
            case id, type, title, description, emoji, importance, actionSuggestion
        }

        init(id: UUID, type: InsightType, title: String, description: String, emoji: String, importance: InsightImportance, relatedData: InsightData?, actionSuggestion: String?) {
            self.id = id
            self.type = type
            self.title = title
            self.description = description
            self.emoji = emoji
            self.importance = importance
            self.relatedData = relatedData
            self.actionSuggestion = actionSuggestion
        }
    }

    /// 인사이트 타입
    enum InsightType: String, CaseIterable, Codable {
        // 시간 관련
        case goldenMoment           // 황금 시간대 발견
        case timePattern            // 시간 패턴
        case perfectTiming          // 완벽한 타이밍

        // 장소 관련
        case hiddenGem              // 숨겨진 명소
        case localFavorite          // 현지인 맛집/장소
        case unexpectedDiscovery    // 예상치 못한 발견

        // 활동 관련
        case diverseExperience      // 다양한 경험
        case deepDive               // 깊이 있는 탐험
        case balancedTrip           // 균형 잡힌 여행

        // 통계 관련
        case distanceMilestone      // 이동 거리 마일스톤
        case photoMoment            // 사진 순간
        case timeWellSpent          // 잘 보낸 시간

        // 특별 발견
        case serendipity            // 우연의 발견
        case personalRecord         // 개인 기록
        case memoryTrigger          // 추억 트리거

        var category: InsightCategory {
            switch self {
            case .goldenMoment, .timePattern, .perfectTiming:
                return .time
            case .hiddenGem, .localFavorite, .unexpectedDiscovery:
                return .place
            case .diverseExperience, .deepDive, .balancedTrip:
                return .activity
            case .distanceMilestone, .photoMoment, .timeWellSpent:
                return .statistics
            case .serendipity, .personalRecord, .memoryTrigger:
                return .special
            }
        }
    }

    enum InsightCategory: String, Codable {
        case time = "시간"
        case place = "장소"
        case activity = "활동"
        case statistics = "통계"
        case special = "특별"

        var emoji: String {
            switch self {
            case .time: return "⏰"
            case .place: return "📍"
            case .activity: return "🎯"
            case .statistics: return "📊"
            case .special: return "✨"
            }
        }
    }

    enum InsightImportance: Int, Comparable, Codable {
        case minor = 1      // 작은 발견
        case notable = 2    // 주목할 만한
        case significant = 3 // 중요한
        case highlight = 4  // 하이라이트
        case exceptional = 5 // 특별한

        static func < (lhs: InsightImportance, rhs: InsightImportance) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var koreanName: String {
            switch self {
            case .minor: return "작은 발견"
            case .notable: return "주목할 만한"
            case .significant: return "중요한 발견"
            case .highlight: return "하이라이트"
            case .exceptional: return "특별한 순간"
            }
        }
    }

    /// 인사이트 관련 데이터
    struct InsightData {
        let clusters: [PlaceCluster]?
        let timeRange: ClosedRange<Date>?
        let location: CLLocationCoordinate2D?
        let value: Double?
        let comparison: String?
    }

    // MARK: - Analysis Context

    struct AnalysisContext {
        let clusters: [PlaceCluster]
        let sceneCategories: [VisionAnalysisService.SceneCategory?]
        let momentScores: [MomentScoreService.MomentScore]
        let travelDNA: TravelDNAService.TravelDNA?
        let totalDistance: Double
        let totalPhotos: Int
    }

    // MARK: - Discover Insights

    /// 인사이트 발굴
    func discoverInsights(from context: AnalysisContext) -> [TravelInsight] {
        logger.info("🔍 [InsightEngine] 인사이트 발굴 시작")

        var insights: [TravelInsight] = []

        // 1. 시간 관련 인사이트
        insights.append(contentsOf: discoverTimeInsights(context: context))

        // 2. 장소 관련 인사이트
        insights.append(contentsOf: discoverPlaceInsights(context: context))

        // 3. 활동 관련 인사이트
        insights.append(contentsOf: discoverActivityInsights(context: context))

        // 4. 통계 인사이트
        insights.append(contentsOf: discoverStatisticsInsights(context: context))

        // 5. 특별 인사이트
        insights.append(contentsOf: discoverSpecialInsights(context: context))

        // 중요도 순으로 정렬
        let sortedInsights = insights.sorted { $0.importance > $1.importance }

        logger.info("🔍 [InsightEngine] 발굴 완료: \(sortedInsights.count)개 인사이트")

        return sortedInsights
    }

    // MARK: - Time Insights

    private func discoverTimeInsights(context: AnalysisContext) -> [TravelInsight] {
        var insights: [TravelInsight] = []

        // 골든아워 발견
        let goldenHourClusters = context.clusters.filter { cluster in
            let hour = Calendar.current.component(.hour, from: cluster.startTime)
            return (hour >= 5 && hour <= 7) || (hour >= 17 && hour <= 19)
        }

        if !goldenHourClusters.isEmpty {
            let goldenCount = goldenHourClusters.count
            let importance: InsightImportance = goldenCount >= 3 ? .highlight : .notable

            insights.append(TravelInsight(
                id: UUID(),
                type: .goldenMoment,
                title: "황금 시간대를 놓치지 않았어요",
                description: "일출이나 일몰 시간대에 \(goldenCount)곳을 방문했습니다. 가장 아름다운 빛을 담았네요!",
                emoji: "🌅",
                importance: importance,
                relatedData: InsightData(clusters: goldenHourClusters, timeRange: nil, location: nil, value: Double(goldenCount), comparison: nil),
                actionSuggestion: "황금 시간대 사진을 모아 특별 앨범을 만들어보세요"
            ))
        }

        // 시간 패턴 분석
        let hourDistribution = analyzeHourDistribution(clusters: context.clusters)
        if let (peakHour, count) = hourDistribution.max(by: { $0.value < $1.value }), count >= 2 {
            let hourString = formatHour(peakHour)

            insights.append(TravelInsight(
                id: UUID(),
                type: .timePattern,
                title: "\(hourString)가 당신의 활동 시간",
                description: "이 여행에서 \(hourString)에 가장 활발하게 움직였어요. \(count)곳을 방문했습니다.",
                emoji: "⏰",
                importance: .notable,
                relatedData: InsightData(clusters: nil, timeRange: nil, location: nil, value: Double(count), comparison: hourString),
                actionSuggestion: nil
            ))
        }

        // 야경 탐험
        let nightClusters = context.clusters.filter { cluster in
            let hour = Calendar.current.component(.hour, from: cluster.startTime)
            return hour >= 20 || hour <= 4
        }

        if nightClusters.count >= 2 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .perfectTiming,
                title: "밤의 탐험가",
                description: "밤 시간대에 \(nightClusters.count)곳을 탐험했어요. 낮과는 다른 매력을 발견했네요!",
                emoji: "🌙",
                importance: .notable,
                relatedData: InsightData(clusters: nightClusters, timeRange: nil, location: nil, value: nil, comparison: nil),
                actionSuggestion: "야경 사진들을 모아보세요"
            ))
        }

        return insights
    }

    // MARK: - Place Insights

    private func discoverPlaceInsights(context: AnalysisContext) -> [TravelInsight] {
        var insights: [TravelInsight] = []

        // 숨겨진 보석 발견 (높은 점수 + 고유성)
        let hiddenGems = zip(context.clusters, context.momentScores).filter { cluster, score in
            score.specialBadges.contains(.hiddenGem) || score.components.uniquenessScore >= 8
        }

        if !hiddenGems.isEmpty {
            let gemNames = hiddenGems.prefix(3).map { $0.0.name }.joined(separator: ", ")

            insights.append(TravelInsight(
                id: UUID(),
                type: .hiddenGem,
                title: "숨겨진 보석을 발견했어요",
                description: "\(gemNames) - 많은 사람들이 지나치는 곳에서 특별한 순간을 찾았습니다.",
                emoji: "💎",
                importance: .highlight,
                relatedData: InsightData(clusters: hiddenGems.map { $0.0 }, timeRange: nil, location: nil, value: nil, comparison: nil),
                actionSuggestion: "이 장소들을 '나만의 명소'로 저장해보세요"
            ))
        }

        // 오래 머문 장소 발견
        let longStayClusters = context.clusters.filter { cluster in
            guard let endTime = cluster.endTime else { return false }
            let duration = endTime.timeIntervalSince(cluster.startTime)
            return duration >= 3600 // 1시간 이상
        }

        if !longStayClusters.isEmpty {
            let longestStay = longStayClusters.max { cluster1, cluster2 in
                let duration1 = (cluster1.endTime ?? cluster1.startTime).timeIntervalSince(cluster1.startTime)
                let duration2 = (cluster2.endTime ?? cluster2.startTime).timeIntervalSince(cluster2.startTime)
                return duration1 < duration2
            }

            if let longest = longestStay, let endTime = longest.endTime {
                let duration = endTime.timeIntervalSince(longest.startTime)
                let hours = Int(duration / 3600)
                let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

                var timeString = ""
                if hours > 0 {
                    timeString = "\(hours)시간"
                    if minutes > 0 {
                        timeString += " \(minutes)분"
                    }
                } else {
                    timeString = "\(minutes)분"
                }

                insights.append(TravelInsight(
                    id: UUID(),
                    type: .localFavorite,
                    title: "시간 가는 줄 몰랐던 곳",
                    description: "\(longest.name)에서 \(timeString)을 보냈어요. 그만큼 매력적인 장소였나봐요!",
                    emoji: "⏳",
                    importance: .significant,
                    relatedData: InsightData(clusters: [longest], timeRange: nil, location: nil, value: duration, comparison: timeString),
                    actionSuggestion: nil
                ))
            }
        }

        // 예상치 못한 장소 발견 (활동 유형과 장면 카테고리 불일치)
        let unexpectedDiscoveries = zip(context.clusters, context.sceneCategories).filter { cluster, scene in
            guard let scene = scene else { return false }
            return scene.toActivityType != cluster.activityType && scene != .unknown
        }

        if unexpectedDiscoveries.count >= 2 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .unexpectedDiscovery,
                title: "계획에 없던 발견들",
                description: "예상과 다른 곳에서 \(unexpectedDiscoveries.count)번의 특별한 순간을 만났어요. 여행의 묘미죠!",
                emoji: "🎲",
                importance: .notable,
                relatedData: InsightData(clusters: unexpectedDiscoveries.map { $0.0 }, timeRange: nil, location: nil, value: nil, comparison: nil),
                actionSuggestion: "우연한 발견들을 기록해두세요"
            ))
        }

        return insights
    }

    // MARK: - Activity Insights

    private func discoverActivityInsights(context: AnalysisContext) -> [TravelInsight] {
        var insights: [TravelInsight] = []

        // 활동 다양성 분석
        let activityTypes = Set(context.clusters.map { $0.activityType })
        let diversityScore = activityTypes.count

        if diversityScore >= 5 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .diverseExperience,
                title: "다양한 경험의 여행",
                description: "\(diversityScore)가지 다른 종류의 활동을 즐겼어요. 풍성한 여행이었네요!",
                emoji: "🎨",
                importance: .highlight,
                relatedData: InsightData(clusters: nil, timeRange: nil, location: nil, value: Double(diversityScore), comparison: nil),
                actionSuggestion: "각 활동별 하이라이트를 정리해보세요"
            ))
        } else if diversityScore <= 2 && context.clusters.count >= 4 {
            let mainActivity = activityTypes.first?.koreanName ?? "활동"

            insights.append(TravelInsight(
                id: UUID(),
                type: .deepDive,
                title: "깊이 있는 \(mainActivity) 탐험",
                description: "한 가지에 집중한 여행이었어요. \(mainActivity)의 진정한 매력을 느꼈을 거예요.",
                emoji: "🔬",
                importance: .notable,
                relatedData: nil,
                actionSuggestion: nil
            ))
        }

        // TravelDNA 기반 균형 분석
        if let dna = context.travelDNA {
            // ActivityBalance가 균형 잡힌 경우 (각 항목이 30~70 범위 내)
            let balance = dna.activityBalance
            let isBalanced = balance.outdoor >= 30 && balance.outdoor <= 70 &&
                             balance.active >= 30 && balance.active <= 70
            if isBalanced {
                insights.append(TravelInsight(
                    id: UUID(),
                    type: .balancedTrip,
                    title: "완벽한 균형의 여행",
                    description: "휴식과 활동, 실내와 야외가 조화롭게 어우러진 여행이었어요.",
                    emoji: "⚖️",
                    importance: .significant,
                    relatedData: nil,
                    actionSuggestion: "이 여행 스타일을 다음에도 참고해보세요"
                ))
            }
        }

        return insights
    }

    // MARK: - Statistics Insights

    private func discoverStatisticsInsights(context: AnalysisContext) -> [TravelInsight] {
        var insights: [TravelInsight] = []

        // 이동 거리 마일스톤
        let distanceKm = context.totalDistance / 1000

        if distanceKm >= 100 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .distanceMilestone,
                title: "대장정을 완료했어요!",
                description: "총 \(String(format: "%.1f", distanceKm))km를 이동했습니다. 정말 대단한 여정이었네요!",
                emoji: "🏆",
                importance: .exceptional,
                relatedData: InsightData(clusters: nil, timeRange: nil, location: nil, value: distanceKm, comparison: nil),
                actionSuggestion: nil
            ))
        } else if distanceKm >= 50 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .distanceMilestone,
                title: "50km 돌파!",
                description: "총 \(String(format: "%.1f", distanceKm))km를 이동했어요. 열심히 돌아다녔네요!",
                emoji: "🚀",
                importance: .highlight,
                relatedData: InsightData(clusters: nil, timeRange: nil, location: nil, value: distanceKm, comparison: nil),
                actionSuggestion: nil
            ))
        } else if distanceKm >= 10 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .distanceMilestone,
                title: "\(String(format: "%.1f", distanceKm))km의 발자취",
                description: "이 여행에서 \(String(format: "%.1f", distanceKm))km를 함께 걸었어요.",
                emoji: "👣",
                importance: .notable,
                relatedData: InsightData(clusters: nil, timeRange: nil, location: nil, value: distanceKm, comparison: nil),
                actionSuggestion: nil
            ))
        }

        // 사진 순간
        if context.totalPhotos >= 100 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .photoMoment,
                title: "100장 이상의 추억",
                description: "\(context.totalPhotos)장의 사진에 이 여행을 담았어요. 소중한 순간들이 가득하네요!",
                emoji: "📸",
                importance: .highlight,
                relatedData: InsightData(clusters: nil, timeRange: nil, location: nil, value: Double(context.totalPhotos), comparison: nil),
                actionSuggestion: "베스트 10장을 선정해보세요"
            ))
        } else if context.totalPhotos >= 50 {
            insights.append(TravelInsight(
                id: UUID(),
                type: .photoMoment,
                title: "\(context.totalPhotos)컷의 이야기",
                description: "많은 순간을 카메라에 담았네요. 각 사진마다 이야기가 있을 거예요.",
                emoji: "📷",
                importance: .notable,
                relatedData: nil,
                actionSuggestion: nil
            ))
        }

        // 여행 시간 분석
        if let firstCluster = context.clusters.first,
           let lastCluster = context.clusters.last,
           let lastEndTime = lastCluster.endTime ?? Optional(lastCluster.startTime) {

            let totalDuration = lastEndTime.timeIntervalSince(firstCluster.startTime)
            let hours = Int(totalDuration / 3600)

            if hours >= 8 {
                insights.append(TravelInsight(
                    id: UUID(),
                    type: .timeWellSpent,
                    title: "\(hours)시간의 알찬 여행",
                    description: "아침부터 저녁까지 알차게 보낸 하루였어요!",
                    emoji: "☀️",
                    importance: .significant,
                    relatedData: InsightData(clusters: nil, timeRange: firstCluster.startTime...lastEndTime, location: nil, value: Double(hours), comparison: nil),
                    actionSuggestion: nil
                ))
            }
        }

        return insights
    }

    // MARK: - Special Insights

    private func discoverSpecialInsights(context: AnalysisContext) -> [TravelInsight] {
        var insights: [TravelInsight] = []

        // 전설의 순간 발견
        let legendaryMoments = context.momentScores.filter { $0.grade == .legendary }

        if !legendaryMoments.isEmpty {
            insights.append(TravelInsight(
                id: UUID(),
                type: .serendipity,
                title: "전설이 될 순간을 만났어요",
                description: "\(legendaryMoments.count)번의 전설적인 순간이 있었어요. 평생 기억될 거예요!",
                emoji: "👑",
                importance: .exceptional,
                relatedData: nil,
                actionSuggestion: "이 순간들은 꼭 별도로 보관하세요"
            ))
        }

        // 배지 컬렉션
        let allBadges = context.momentScores.flatMap { $0.specialBadges }
        let uniqueBadges = Set(allBadges)

        if uniqueBadges.count >= 5 {
            let badgeEmojis = uniqueBadges.prefix(5).map { $0.emoji }.joined(separator: " ")

            insights.append(TravelInsight(
                id: UUID(),
                type: .personalRecord,
                title: "배지 컬렉터",
                description: "\(uniqueBadges.count)종류의 특별 배지를 획득했어요! \(badgeEmojis)",
                emoji: "🏅",
                importance: .highlight,
                relatedData: nil,
                actionSuggestion: "모든 배지 종류를 모아보세요"
            ))
        }

        // 첫 장소와 마지막 장소 연결
        if context.clusters.count >= 3,
           let firstPlace = context.clusters.first,
           let lastPlace = context.clusters.last {

            let firstLocation = CLLocation(latitude: firstPlace.centerCoordinate.latitude, longitude: firstPlace.centerCoordinate.longitude)
            let lastLocation = CLLocation(latitude: lastPlace.centerCoordinate.latitude, longitude: lastPlace.centerCoordinate.longitude)
            let returnDistance = firstLocation.distance(from: lastLocation)

            if returnDistance < 500 { // 500m 이내로 돌아옴
                insights.append(TravelInsight(
                    id: UUID(),
                    type: .memoryTrigger,
                    title: "원점으로 돌아온 여정",
                    description: "시작점 근처에서 여행을 마무리했어요. 완벽한 원을 그린 하루였네요.",
                    emoji: "🔄",
                    importance: .notable,
                    relatedData: InsightData(clusters: [firstPlace, lastPlace], timeRange: nil, location: nil, value: returnDistance, comparison: nil),
                    actionSuggestion: nil
                ))
            }
        }

        // DNA 기반 특별 인사이트
        if let dna = context.travelDNA {
            if dna.explorationScore >= 80 {
                insights.append(TravelInsight(
                    id: UUID(),
                    type: .personalRecord,
                    title: "진정한 탐험가",
                    description: "탐험 지수 \(dna.explorationScore)점! 새로운 곳을 발견하는 걸 즐기시는군요.",
                    emoji: "🧭",
                    importance: .significant,
                    relatedData: nil,
                    actionSuggestion: nil
                ))
            }

            if dna.cultureScore >= 80 {
                insights.append(TravelInsight(
                    id: UUID(),
                    type: .personalRecord,
                    title: "문화 애호가",
                    description: "문화 지수 \(dna.cultureScore)점! 그 지역의 문화를 깊이 경험했어요.",
                    emoji: "🎭",
                    importance: .significant,
                    relatedData: nil,
                    actionSuggestion: nil
                ))
            }
        }

        return insights
    }

    // MARK: - Helper Methods

    private func analyzeHourDistribution(clusters: [PlaceCluster]) -> [Int: Int] {
        var distribution: [Int: Int] = [:]

        for cluster in clusters {
            let hour = Calendar.current.component(.hour, from: cluster.startTime)
            distribution[hour, default: 0] += 1
        }

        return distribution
    }

    private func formatHour(_ hour: Int) -> String {
        switch hour {
        case 5..<8: return "이른 아침"
        case 8..<11: return "오전"
        case 11..<14: return "점심 시간대"
        case 14..<17: return "오후"
        case 17..<20: return "저녁 시간대"
        case 20..<23: return "밤"
        default: return "새벽"
        }
    }
}

// MARK: - Insight Summary

extension InsightEngine {
    /// 인사이트 요약 생성
    func generateSummary(from insights: [TravelInsight]) -> InsightSummary {
        let topInsights = insights.prefix(5).map { $0 }
        let categories = Dictionary(grouping: insights, by: { $0.type.category })

        let highlightCount = insights.filter { $0.importance >= .highlight }.count
        let specialCount = insights.filter { $0.importance == .exceptional }.count

        var summaryText = ""
        if specialCount > 0 {
            summaryText = "이 여행에서 \(specialCount)개의 특별한 발견이 있었어요!"
        } else if highlightCount > 0 {
            summaryText = "\(highlightCount)개의 하이라이트 인사이트를 발견했어요."
        } else {
            summaryText = "총 \(insights.count)개의 인사이트를 발견했습니다."
        }

        return InsightSummary(
            totalCount: insights.count,
            topInsights: topInsights,
            byCategory: categories,
            summaryText: summaryText
        )
    }

    struct InsightSummary {
        let totalCount: Int
        let topInsights: [TravelInsight]
        let byCategory: [InsightCategory: [TravelInsight]]
        let summaryText: String
    }
}

// MARK: - ActivityType Extension for InsightEngine

extension ActivityType {
    var koreanName: String {
        switch self {
        case .tourist: return "관광"
        case .cafe: return "카페"
        case .restaurant: return "맛집"
        case .culture: return "문화"
        case .shopping: return "쇼핑"
        case .nature: return "자연"
        case .beach: return "해변"
        case .mountain: return "산"
        case .nightlife: return "나이트라이프"
        case .transportation: return "이동"
        case .accommodation: return "숙소"
        case .airport: return "공항"
        case .unknown: return "기타"
        case .other: return "기타"
        }
    }
}
