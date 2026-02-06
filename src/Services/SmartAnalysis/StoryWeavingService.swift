import Foundation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "StoryWeaving")

/// AI 여행 스토리텔링 서비스
/// 분석 결과를 기반으로 감성적인 여행 이야기 생성
/// BYOK AI 없이도 로컬에서 스토리 생성 가능
class StoryWeavingService {

    // MARK: - Story Output

    struct TravelStory: Codable {
        let title: String               // 스토리 제목
        let opening: String             // 오프닝 (여행 시작)
        let chapters: [StoryChapter]    // 챕터별 이야기
        let climax: String              // 클라이맥스 (하이라이트)
        let closing: String             // 엔딩 (마무리)
        let tagline: String             // 한줄 요약
        let mood: StoryMood             // 전체 분위기
        let keywords: [String]          // 키워드

        /// 전체 스토리 텍스트
        var fullText: String {
            var text = "# \(title)\n\n"
            text += "\(opening)\n\n"

            for chapter in chapters {
                text += "## \(chapter.title)\n"
                text += "\(chapter.content)\n\n"
            }

            if !climax.isEmpty {
                text += "## ✨ 하이라이트\n"
                text += "\(climax)\n\n"
            }

            text += "\(closing)\n\n"
            text += "---\n*\(tagline)*"

            return text
        }

        /// 짧은 버전 (공유용)
        var shortVersion: String {
            "\(title)\n\n\(tagline)"
        }
    }

    // MARK: - Story Chapter

    struct StoryChapter: Codable {
        let title: String
        let content: String
        let placeName: String
        let emoji: String
        let momentScore: Int?
    }

    // MARK: - Story Mood

    enum StoryMood: String, CaseIterable, Codable {
        case adventurous    // 모험적인
        case romantic       // 로맨틱한
        case peaceful       // 평화로운
        case exciting       // 신나는
        case reflective     // 회고적인
        case heartwarming   // 따뜻한
        case inspiring      // 영감을 주는

        var koreanName: String {
            switch self {
            case .adventurous: return "모험적인"
            case .romantic: return "로맨틱한"
            case .peaceful: return "평화로운"
            case .exciting: return "신나는"
            case .reflective: return "추억이 깃든"
            case .heartwarming: return "따뜻한"
            case .inspiring: return "영감을 주는"
            }
        }

        var emoji: String {
            switch self {
            case .adventurous: return "🏔️"
            case .romantic: return "💕"
            case .peaceful: return "🌿"
            case .exciting: return "🎉"
            case .reflective: return "📷"
            case .heartwarming: return "💝"
            case .inspiring: return "✨"
            }
        }
    }

    // MARK: - Story Context

    struct StoryContext {
        let clusters: [PlaceCluster]
        let travelDNA: TravelDNAService.TravelDNA?
        let momentScores: [MomentScoreService.MomentScore]
        let sceneDescriptions: [String]
        let startDate: Date
        let endDate: Date
        let totalDistance: Double
        let photoCount: Int
    }

    // MARK: - Generate Story

    /// 여행 스토리 생성
    func generateStory(from context: StoryContext) -> TravelStory {
        logger.info("📖 [StoryWeaving] 스토리 생성 시작")

        // 1. 분위기 결정
        let mood = determineMood(context: context)

        // 2. 제목 생성
        let title = generateTitle(context: context, mood: mood)

        // 3. 오프닝 생성
        let opening = generateOpening(context: context, mood: mood)

        // 4. 챕터 생성
        let chapters = generateChapters(context: context, mood: mood)

        // 5. 클라이맥스 (하이라이트) 찾기
        let climax = generateClimax(context: context)

        // 6. 엔딩 생성
        let closing = generateClosing(context: context, mood: mood)

        // 7. 태그라인 생성
        let tagline = generateTagline(context: context, mood: mood)

        // 8. 키워드 추출
        let keywords = extractKeywords(context: context)

        let story = TravelStory(
            title: title,
            opening: opening,
            chapters: chapters,
            climax: climax,
            closing: closing,
            tagline: tagline,
            mood: mood,
            keywords: keywords
        )

        logger.info("📖 [StoryWeaving] 스토리 생성 완료: \(title)")

        return story
    }

    // MARK: - Determine Mood

    private func determineMood(context: StoryContext) -> StoryMood {
        // TravelDNA 기반 분위기 결정
        if let dna = context.travelDNA {
            switch dna.primaryType {
            case .adventurer:
                return .adventurous
            case .natureLover:
                return .peaceful
            case .foodie:
                return .heartwarming
            case .culturist:
                return .inspiring
            case .relaxer:
                return .peaceful
            default:
                break
            }
        }

        // 활동 유형 기반
        let activities = context.clusters.map { $0.activityType }

        if activities.contains(.beach) || activities.contains(.mountain) {
            return .adventurous
        }
        if activities.contains(.cafe) && activities.contains(.restaurant) {
            return .heartwarming
        }
        if activities.contains(.culture) {
            return .inspiring
        }

        return .reflective
    }

    // MARK: - Generate Title

    private func generateTitle(context: StoryContext, mood: StoryMood) -> String {
        let calendar = Calendar.current
        let dayCount = calendar.dateComponents([.day], from: context.startDate, to: context.endDate).day ?? 0
        let mainPlace = context.clusters.first?.displayName ?? "여행"

        if dayCount == 0 {
            return "\(mainPlace) 당일 여행"
        } else {
            return "\(mainPlace) \(dayCount + 1)일 여행"
        }
    }

    // MARK: - Generate Opening

    private func generateOpening(context: StoryContext, mood: StoryMood) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"

        let dateString = formatter.string(from: context.startDate)
        let firstPlace = context.clusters.first?.displayName ?? "출발지"
        let lastPlace = context.clusters.last?.displayName ?? firstPlace
        let placeCount = context.clusters.count

        if firstPlace == lastPlace {
            return "\(dateString), \(firstPlace). \(placeCount)곳 방문, \(context.photoCount)장 촬영."
        } else {
            return "\(dateString), \(firstPlace)에서 \(lastPlace)까지. \(placeCount)곳 방문, \(context.photoCount)장 촬영."
        }
    }

    // MARK: - Generate Chapters

    private func generateChapters(context: StoryContext, mood: StoryMood) -> [StoryChapter] {
        var chapters: [StoryChapter] = []

        for (index, cluster) in context.clusters.enumerated() {
            let score = index < context.momentScores.count ? context.momentScores[index] : nil

            let chapter = generateChapter(
                cluster: cluster,
                index: index,
                totalCount: context.clusters.count,
                mood: mood,
                score: score
            )
            chapters.append(chapter)
        }

        return chapters
    }

    private func generateChapter(
        cluster: PlaceCluster,
        index: Int,
        totalCount: Int,
        mood: StoryMood,
        score: MomentScoreService.MomentScore?
    ) -> StoryChapter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: cluster.startTime)

        let placeName = cluster.displayName
        let emoji = cluster.displayEmoji
        let activity = cluster.activityType

        let title = "\(emoji) \(placeName)"

        // 사실 기반 챕터 내용
        var content = "\(timeString), \(placeName). \(activity.displayName)"

        // 체류 시간
        if let endTime = cluster.endTime {
            let duration = Int(endTime.timeIntervalSince(cluster.startTime) / 60)
            if duration > 0 {
                content += ", \(duration)분 체류"
            }
        }

        // 사진 수
        content += ", \(cluster.photos.count)장 촬영."

        // 높은 점수면 점수 정보 추가
        if let momentScore = score, momentScore.totalScore >= 80 {
            content += " \(momentScore.totalScore)점(\(momentScore.grade.rawValue))."
        }

        return StoryChapter(
            title: title,
            content: content,
            placeName: placeName,
            emoji: emoji,
            momentScore: score?.totalScore
        )
    }

    // MARK: - Generate Climax

    private func generateClimax(context: StoryContext) -> String {
        guard let bestMoment = context.momentScores.enumerated().max(by: { $0.element.totalScore < $1.element.totalScore }),
              bestMoment.offset < context.clusters.count else {
            return ""
        }

        let cluster = context.clusters[bestMoment.offset]
        let score = bestMoment.element

        var climax = "하이라이트: \(cluster.displayName), \(score.totalScore)점(\(score.grade.rawValue))."

        if !score.specialBadges.isEmpty {
            let badgeNames = score.specialBadges.prefix(3).map { $0.koreanName }
            climax += " 배지: \(badgeNames.joined(separator: ", "))."
        }

        return climax
    }

    // MARK: - Generate Closing

    private func generateClosing(context: StoryContext, mood: StoryMood) -> String {
        let placeCount = context.clusters.count
        let photoCount = context.photoCount
        let distanceKm = String(format: "%.1f", context.totalDistance / 1000)

        return "\(placeCount)곳 방문, 총 \(distanceKm)km 이동, \(photoCount)장 촬영."
    }

    // MARK: - Generate Tagline

    private func generateTagline(context: StoryContext, mood: StoryMood) -> String {
        let firstPlace = context.clusters.first?.displayName ?? "출발지"
        let lastPlace = context.clusters.last?.displayName ?? firstPlace
        let distanceKm = String(format: "%.1f", context.totalDistance / 1000)

        if firstPlace == lastPlace {
            return "\(firstPlace), \(distanceKm)km의 여정"
        } else {
            return "\(firstPlace)에서 \(lastPlace)까지, \(distanceKm)km"
        }
    }

    // MARK: - Extract Keywords

    private func extractKeywords(context: StoryContext) -> [String] {
        var keywords: Set<String> = []

        // 장소 이름에서 추출
        for cluster in context.clusters {
            keywords.insert(cluster.displayName)
        }

        // 활동 타입에서 추출
        for cluster in context.clusters {
            keywords.insert(cluster.activityType.displayName)
        }

        // TravelDNA에서 추출
        if let dna = context.travelDNA {
            keywords.insert(dna.primaryType.koreanName)
            for trait in dna.traits {
                keywords.insert(trait.koreanName)
            }
        }

        return Array(keywords).prefix(10).map { $0 }
    }
}
