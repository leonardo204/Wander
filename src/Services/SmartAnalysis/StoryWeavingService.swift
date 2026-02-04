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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        // 날짜 정보
        let calendar = Calendar.current
        let dayCount = calendar.dateComponents([.day], from: context.startDate, to: context.endDate).day ?? 0

        // 대표 장소
        let mainPlace = context.clusters.first?.displayName ?? "여행"

        // 분위기별 제목 템플릿
        switch mood {
        case .adventurous:
            return "\(mainPlace)에서의 모험"
        case .romantic:
            return "\(mainPlace), 낭만의 기록"
        case .peaceful:
            return "\(mainPlace)에서 찾은 평화"
        case .exciting:
            return "신나는 \(mainPlace) 탐험"
        case .reflective:
            if dayCount == 0 {
                formatter.dateFormat = "M월 d일"
                return "\(formatter.string(from: context.startDate)), \(mainPlace)의 하루"
            } else {
                return "\(dayCount + 1)일간의 \(mainPlace) 여정"
            }
        case .heartwarming:
            return "\(mainPlace)에서의 따뜻한 순간들"
        case .inspiring:
            return "\(mainPlace)이 선물한 영감"
        }
    }

    // MARK: - Generate Opening

    private func generateOpening(context: StoryContext, mood: StoryMood) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"

        let dateString = formatter.string(from: context.startDate)
        let firstPlace = context.clusters.first?.displayName ?? "새로운 곳"

        let templates: [StoryMood: [String]] = [
            .adventurous: [
                "\(dateString), 새로운 모험의 시작. \(firstPlace)에 첫 발을 내딛는 순간, 설렘이 가득 찼습니다.",
                "떠나자, \(firstPlace)로! \(dateString)의 아침, 모험가의 마음으로 여정을 시작했습니다."
            ],
            .peaceful: [
                "\(dateString), 일상에서 벗어나 \(firstPlace)에서의 힐링이 시작되었습니다.",
                "바쁜 일상을 뒤로하고, \(firstPlace)의 평화로움 속으로. \(dateString)의 기록입니다."
            ],
            .heartwarming: [
                "\(dateString), 맛있는 음식과 따뜻한 순간들이 기다리는 \(firstPlace)로 향했습니다.",
                "향기로운 커피 한 잔과 함께, \(firstPlace)에서의 \(dateString)이 시작되었습니다."
            ],
            .reflective: [
                "\(dateString), \(firstPlace)에서의 특별한 하루가 시작되었습니다.",
                "사진첩을 넘기며 떠올리는 \(dateString), \(firstPlace)에서의 순간들."
            ],
            .inspiring: [
                "\(dateString), 영감을 찾아 떠난 \(firstPlace)에서의 여정이 시작되었습니다.",
                "새로운 발견과 영감이 기다리는 \(firstPlace)로. \(dateString)의 탐험 기록."
            ],
            .romantic: [
                "\(dateString), 로맨틱한 \(firstPlace)에서의 이야기가 시작되었습니다.",
                "낭만이 가득한 \(firstPlace), \(dateString)의 아름다운 시작."
            ],
            .exciting: [
                "\(dateString), 신나는 \(firstPlace) 탐험이 시작되었습니다!",
                "두근두근, \(firstPlace)로 출발! \(dateString)의 신나는 하루가 펼쳐집니다."
            ]
        ]

        let options = templates[mood] ?? templates[.reflective]!
        return options.randomElement() ?? options[0]
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

        // 챕터 제목
        let title = "\(emoji) \(placeName)"

        // 챕터 내용 생성
        var content = ""

        // 시간 정보
        content += "\(timeString), "

        // 활동 유형에 따른 내용
        switch activity {
        case .cafe:
            content += "향긋한 커피 향이 가득한 카페에서 잠시 쉬어갑니다. "
            if cluster.photos.count > 5 {
                content += "이 분위기를 담고 싶어 여러 장의 사진을 남겼습니다."
            } else {
                content += "창밖 풍경을 바라보며 여유로운 시간을 보냈습니다."
            }

        case .restaurant:
            content += "현지의 맛을 경험하는 시간. "
            content += "\(placeName)에서 특별한 한 끼를 즐겼습니다. "
            content += "맛있는 음식과 함께 행복한 순간이었습니다."

        case .beach:
            content += "푸른 바다가 펼쳐진 \(placeName)에 도착했습니다. "
            content += "파도 소리를 들으며 여유로운 시간을 보냈습니다. "
            content += "바다의 평화로움이 마음을 채웁니다."

        case .mountain:
            content += "\(placeName)의 장엄한 풍경 앞에 섰습니다. "
            content += "자연의 위대함을 온몸으로 느끼는 순간입니다. "
            content += "깊은 숨을 들이쉬며 힐링의 시간을 가졌습니다."

        case .culture:
            content += "역사와 문화가 살아 숨쉬는 \(placeName)을 방문했습니다. "
            content += "과거와 현재가 공존하는 이 공간에서 "
            content += "새로운 영감을 얻었습니다."

        case .tourist:
            content += "\(placeName)에서 특별한 순간을 담았습니다. "
            content += "여행의 기억을 사진으로 남기며 "
            content += "이 순간을 오래 기억하고 싶었습니다."

        case .shopping:
            content += "다양한 물건들 사이를 구경하며 걸었습니다. "
            content += "\(placeName)에서 특별한 기념품을 발견했습니다."

        default:
            content += "\(placeName)에서 시간을 보냈습니다. "
            content += "여행 중 우연히 마주친 이 장소가 "
            content += "특별한 추억이 되었습니다."
        }

        // 높은 점수면 추가 멘트
        if let momentScore = score, momentScore.totalScore >= 80 {
            content += " 이 여행에서 가장 기억에 남는 순간 중 하나입니다."
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
        // 가장 높은 점수의 순간 찾기
        guard let bestMoment = context.momentScores.enumerated().max(by: { $0.element.totalScore < $1.element.totalScore }),
              bestMoment.offset < context.clusters.count else {
            return ""
        }

        let cluster = context.clusters[bestMoment.offset]
        let score = bestMoment.element

        var climax = "이 여행의 하이라이트는 바로 \(cluster.displayName)에서의 순간입니다. "

        if score.grade == .legendary {
            climax += "전설적인 순간으로 기록될 만큼 특별했습니다. "
        } else if score.grade == .epic {
            climax += "잊지 못할 특별한 경험이었습니다. "
        }

        // 배지가 있으면 언급
        if !score.specialBadges.isEmpty {
            let badgeNames = score.specialBadges.prefix(2).map { $0.koreanName }
            climax += "\(badgeNames.joined(separator: ", ")) 순간이었습니다."
        }

        return climax
    }

    // MARK: - Generate Closing

    private func generateClosing(context: StoryContext, mood: StoryMood) -> String {
        let placeCount = context.clusters.count
        let photoCount = context.photoCount

        let templates: [StoryMood: [String]] = [
            .adventurous: [
                "\(placeCount)곳의 장소, \(photoCount)장의 사진. 이 모험의 기록은 언제 꺼내봐도 가슴 뛰게 할 것입니다.",
                "모험은 끝났지만, 이 기억은 영원히 남을 것입니다."
            ],
            .peaceful: [
                "평화로웠던 시간들이 마음 깊이 남습니다. 일상으로 돌아가도 이 평온함을 잊지 않을 것입니다.",
                "\(placeCount)곳에서 찾은 힐링. 다시 일상에 지칠 때 이 순간들을 꺼내볼 것입니다."
            ],
            .heartwarming: [
                "맛있는 음식, 따뜻한 순간들. \(photoCount)장의 사진에 담긴 행복을 오래 간직하겠습니다.",
                "따뜻했던 이 여행의 온기가 오래도록 마음에 남습니다."
            ],
            .reflective: [
                "이렇게 \(placeCount)곳을 돌아본 여정이 마무리됩니다. \(photoCount)장의 사진이 이 순간들을 증명합니다.",
                "돌아보면 모든 순간이 소중했습니다. 이 기록이 언젠가 다시 미소 짓게 할 것입니다."
            ],
            .inspiring: [
                "영감으로 가득했던 여정이 마무리됩니다. 이 경험이 새로운 시작이 될 것입니다.",
                "\(placeCount)곳에서 받은 영감을 마음에 담고 일상으로 돌아갑니다."
            ],
            .romantic: [
                "로맨틱했던 순간들이 아름다운 추억으로 남습니다.",
                "낭만 가득했던 이 여행, 다시 떠나고 싶어집니다."
            ],
            .exciting: [
                "신났던 시간들! \(photoCount)장의 사진이 그 증거입니다. 다음 모험이 벌써 기대됩니다!",
                "즐거웠던 여정이 끝났지만, 이 기억은 계속 웃게 만들 것입니다."
            ]
        ]

        let options = templates[mood] ?? templates[.reflective]!
        return options.randomElement() ?? options[0]
    }

    // MARK: - Generate Tagline

    private func generateTagline(context: StoryContext, mood: StoryMood) -> String {
        let mainPlace = context.clusters.first?.displayName ?? "여행"

        switch mood {
        case .adventurous:
            return "모험이 기다리는 곳, \(mainPlace)"
        case .peaceful:
            return "\(mainPlace)에서 찾은 나만의 평화"
        case .heartwarming:
            return "맛있고 따뜻했던, \(mainPlace)의 기억"
        case .reflective:
            return "\(mainPlace), 소중한 순간들의 기록"
        case .inspiring:
            return "\(mainPlace)이 선물한 새로운 영감"
        case .romantic:
            return "낭만이 머무는 곳, \(mainPlace)"
        case .exciting:
            return "신나는 \(mainPlace) 어드벤처!"
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
