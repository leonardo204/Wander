import Foundation
import Photos
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "AIEnhancement")

/// AI 다듬기 서비스
/// 온디바이스 분석의 사실 기반 텍스트를 AI가 보정 + 감성 추가
/// 팩트:감성 = 7:3, 멀티모달(Gemini) 이미지 분석 지원
final class AIEnhancementService {

    // MARK: - Build Input

    /// AnalysisResult에서 AI에 전달할 데이터 추출
    static func buildInput(from result: AnalysisResult) -> AIEnhancementInput {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy년 M월 d일"
        dateFormatter.locale = Locale(identifier: "ko_KR")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // 장소 정보
        let places: [AIEnhancementInput.PlaceInput] = result.places.enumerated().map { index, place in
            let score = index < result.momentScores.count ? result.momentScores[index] : nil
            return AIEnhancementInput.PlaceInput(
                name: place.name,
                address: place.address,
                activityType: place.activityType.rawValue,
                visitTime: timeFormatter.string(from: place.startTime),
                photoCount: place.photos.count,
                durationMinutes: place.endTime.map { Int($0.timeIntervalSince(place.startTime) / 60) },
                sceneCategory: place.sceneCategory?.rawValue,
                badges: score?.specialBadges.map { $0.rawValue } ?? [],
                momentScore: score?.totalScore,
                momentGrade: score?.grade.rawValue,
                highlights: score?.highlights ?? []
            )
        }

        // 스토리 컨텍스트
        let storyContext: AIEnhancementInput.StoryContextInput? = result.travelStory.map { story in
            AIEnhancementInput.StoryContextInput(
                mood: story.mood.rawValue,
                currentTitle: story.title,
                currentOpening: story.opening,
                currentChapters: story.chapters.map { chapter in
                    AIEnhancementInput.ChapterInput(
                        placeName: chapter.placeName,
                        currentContent: chapter.content,
                        emoji: chapter.emoji
                    )
                },
                currentClimax: story.climax,
                currentClosing: story.closing,
                currentTagline: story.tagline
            )
        }

        // 인사이트
        let insights: [AIEnhancementInput.InsightInput] = result.insights.map { insight in
            AIEnhancementInput.InsightInput(
                type: insight.type.rawValue,
                currentTitle: insight.title,
                currentDescription: insight.description,
                currentActionSuggestion: insight.actionSuggestion,
                emoji: insight.emoji,
                importance: insight.importance.rawValue
            )
        }

        // TravelDNA
        let travelDNA: AIEnhancementInput.TravelDNAInput? = result.travelDNA.map { dna in
            AIEnhancementInput.TravelDNAInput(
                primaryType: dna.primaryType.koreanName,
                secondaryType: dna.secondaryType?.koreanName,
                traits: dna.traits.map { $0.rawValue },
                explorationScore: dna.explorationScore,
                socialScore: dna.socialScore,
                cultureScore: dna.cultureScore,
                dnaCode: dna.dnaCode,
                currentDescription: dna.description
            )
        }

        // 전체 여행 점수
        let tripScore: AIEnhancementInput.TripScoreInput? = result.tripScore.map { score in
            AIEnhancementInput.TripScoreInput(
                averageScore: score.averageScore,
                peakMomentScore: score.peakMomentScore,
                tripGrade: score.tripGrade.rawValue,
                currentSummary: score.summary
            )
        }

        // 순간 점수
        let momentScores: [AIEnhancementInput.MomentScoreInput] = zip(result.places, result.momentScores).map { place, score in
            AIEnhancementInput.MomentScoreInput(
                placeName: place.name,
                totalScore: score.totalScore,
                grade: score.grade.rawValue,
                currentHighlights: score.highlights
            )
        }

        return AIEnhancementInput(
            title: result.title,
            startDate: dateFormatter.string(from: result.startDate),
            endDate: dateFormatter.string(from: result.endDate),
            totalDistance: result.totalDistance,
            photoCount: result.photoCount,
            places: places,
            storyContext: storyContext,
            insights: insights,
            travelDNA: travelDNA,
            tripScore: tripScore,
            momentScores: momentScores
        )
    }

    // MARK: - Enhance

    /// AI로 분석 결과 다듬기 (멀티모달 이미지 지원)
    /// - Parameters:
    ///   - result: 원본 분석 결과
    ///   - provider: AI 프로바이더
    ///   - selectedAssets: 선택된 사진 (멀티모달 전송용, 선택적)
    /// - Returns: AI로 보정 + 감성 추가된 분석 결과
    static func enhance(
        result: AnalysisResult,
        provider: AIProvider,
        selectedAssets: [PHAsset] = []
    ) async throws -> AIEnhancementResult {
        let input = buildInput(from: result)
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(from: input)

        logger.info("✨ [AI Enhancement] 시작 - provider: \(provider.displayName), places: \(input.places.count)개")
        logger.info("✨ [AI Enhancement] userPrompt 길이: \(userPrompt.count)자")

        let service = AIServiceFactory.createService(for: provider)

        // 멀티모달: Gemini 프로바이더 + 사진 있을 때 이미지 추출
        let images: [AIImageData]
        if provider == .google && !selectedAssets.isEmpty {
            images = await extractRepresentativeImages(
                from: result.places,
                selectedAssets: selectedAssets
            )
            logger.info("✨ [AI Enhancement] 멀티모달 이미지 \(images.count)장 준비")
        } else {
            images = []
        }

        let response: String
        if !images.isEmpty {
            response = try await service.generateContentWithImages(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                images: images,
                maxTokens: 4096,
                temperature: 0.7
            )
        } else {
            response = try await service.generateContent(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                maxTokens: 4096,
                temperature: 0.7
            )
        }

        logger.info("✨ [AI Enhancement] 응답 수신 - length: \(response.count)자")

        let enhancementResult = try parseResponse(response)
        logger.info("✨ [AI Enhancement] 파싱 성공")

        return enhancementResult
    }

    /// AI 결과를 AnalysisResult에 머지
    /// nil이 아닌 필드만 교체, 나머지는 원본 유지
    static func apply(
        _ enhancement: AIEnhancementResult,
        to result: inout AnalysisResult
    ) {
        // 1. 제목
        if let enhancedTitle = enhancement.enhancedTitle, !enhancedTitle.isEmpty {
            result.title = enhancedTitle
            logger.info("✨ [Merge] 제목 교체: \(enhancedTitle)")
        }

        // 2. 스토리
        if let enhancedStory = enhancement.story, let originalStory = result.travelStory {
            result.travelStory = mergeStory(enhanced: enhancedStory, original: originalStory)
            logger.info("✨ [Merge] 스토리 교체 완료")
        }

        // 3. 인사이트
        if let enhancedInsights = enhancement.insights, !enhancedInsights.isEmpty {
            result.insights = mergeInsights(enhanced: enhancedInsights, originals: result.insights)
            logger.info("✨ [Merge] 인사이트 교체: \(enhancedInsights.count)개")
        }

        // 4. 여행 점수 요약
        if let summary = enhancement.tripScoreSummary, !summary.isEmpty,
           let originalScore = result.tripScore {
            result.tripScore = MomentScoreService.TripOverallScore(
                averageScore: originalScore.averageScore,
                peakMomentScore: originalScore.peakMomentScore,
                totalBadges: originalScore.totalBadges,
                tripGrade: originalScore.tripGrade,
                summary: summary
            )
            logger.info("✨ [Merge] 여행 점수 요약 교체")
        }

        // 5. 순간 하이라이트
        if let enhancedHighlights = enhancement.momentHighlights, !enhancedHighlights.isEmpty {
            result.momentScores = mergeMomentHighlights(
                enhanced: enhancedHighlights,
                originals: result.momentScores,
                places: result.places
            )
            logger.info("✨ [Merge] 순간 하이라이트 교체: \(enhancedHighlights.count)개")
        }

        // 6. TravelDNA 설명 → aiEnhancedDNADescription 오버레이
        if let dnaDesc = enhancement.travelDNADescription, !dnaDesc.isEmpty {
            result.aiEnhancedDNADescription = dnaDesc
            logger.info("✨ [Merge] TravelDNA 설명 교체")
        }

        // 7. 사실 보정 (corrections)
        if let corrections = enhancement.corrections, !corrections.isEmpty {
            applyCorrections(corrections, to: &result)
        }

        // AI 개선 상태 업데이트
        result.isAIEnhanced = true
        result.aiEnhancedAt = Date()
    }

    // MARK: - TravelRecord Support (기록 상세 화면용)

    /// TravelRecord에서 AI에 전달할 데이터 추출
    static func buildInput(from record: TravelRecord) -> AIEnhancementInput {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy년 M월 d일"
        dateFormatter.locale = Locale(identifier: "ko_KR")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // 장소 정보: TravelRecord → days → places
        var places: [AIEnhancementInput.PlaceInput] = []
        let sortedDays = record.days.sorted { $0.dayNumber < $1.dayNumber }
        for day in sortedDays {
            for place in day.places.sorted(by: { $0.order < $1.order }) {
                places.append(AIEnhancementInput.PlaceInput(
                    name: place.name,
                    address: place.address,
                    activityType: place.activityLabel,
                    visitTime: timeFormatter.string(from: place.startTime),
                    photoCount: place.photos.count,
                    durationMinutes: nil,
                    sceneCategory: nil,
                    badges: [],
                    momentScore: nil,
                    momentGrade: nil,
                    highlights: []
                ))
            }
        }

        // 스토리 컨텍스트
        let storyContext: AIEnhancementInput.StoryContextInput? = record.travelStory.map { story in
            AIEnhancementInput.StoryContextInput(
                mood: story.mood.rawValue,
                currentTitle: story.title,
                currentOpening: story.opening,
                currentChapters: story.chapters.map { chapter in
                    AIEnhancementInput.ChapterInput(
                        placeName: chapter.placeName,
                        currentContent: chapter.content,
                        emoji: chapter.emoji
                    )
                },
                currentClimax: story.climax,
                currentClosing: story.closing,
                currentTagline: story.tagline
            )
        }

        // 인사이트
        let insights: [AIEnhancementInput.InsightInput] = record.insights.map { insight in
            AIEnhancementInput.InsightInput(
                type: insight.type.rawValue,
                currentTitle: insight.title,
                currentDescription: insight.description,
                currentActionSuggestion: insight.actionSuggestion,
                emoji: insight.emoji,
                importance: insight.importance.rawValue
            )
        }

        // TravelDNA
        let travelDNA: AIEnhancementInput.TravelDNAInput? = record.travelDNA.map { dna in
            AIEnhancementInput.TravelDNAInput(
                primaryType: dna.primaryType.koreanName,
                secondaryType: dna.secondaryType?.koreanName,
                traits: dna.traits.map { $0.rawValue },
                explorationScore: dna.explorationScore,
                socialScore: dna.socialScore,
                cultureScore: dna.cultureScore,
                dnaCode: dna.dnaCode,
                currentDescription: record.aiEnhancedDNADescription ?? dna.description
            )
        }

        // 여행 점수
        let tripScore: AIEnhancementInput.TripScoreInput? = record.tripScore.map { score in
            AIEnhancementInput.TripScoreInput(
                averageScore: score.averageScore,
                peakMomentScore: score.peakMomentScore,
                tripGrade: score.tripGrade.rawValue,
                currentSummary: score.summary
            )
        }

        return AIEnhancementInput(
            title: record.title,
            startDate: dateFormatter.string(from: record.startDate),
            endDate: dateFormatter.string(from: record.endDate),
            totalDistance: record.totalDistance,
            photoCount: record.photoCount,
            places: places,
            storyContext: storyContext,
            insights: insights,
            travelDNA: travelDNA,
            tripScore: tripScore,
            momentScores: []  // TravelRecord에는 MomentScore가 저장되지 않음
        )
    }

    /// TravelRecord용 AI 다듬기
    static func enhance(
        record: TravelRecord,
        provider: AIProvider
    ) async throws -> AIEnhancementResult {
        let input = buildInput(from: record)
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(from: input)

        logger.info("✨ [AI Enhancement] 기록 다듬기 시작 - provider: \(provider.displayName), places: \(input.places.count)개")

        let service = AIServiceFactory.createService(for: provider)
        let response = try await service.generateContent(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: 4096,
            temperature: 0.7
        )

        logger.info("✨ [AI Enhancement] 기록 응답 수신 - length: \(response.count)자")
        return try parseResponse(response)
    }

    /// AI 결과를 TravelRecord에 직접 머지
    static func apply(
        _ enhancement: AIEnhancementResult,
        to record: TravelRecord
    ) {
        // 1. 제목
        if let enhancedTitle = enhancement.enhancedTitle, !enhancedTitle.isEmpty {
            record.title = enhancedTitle
            logger.info("✨ [Merge/Record] 제목 교체: \(enhancedTitle)")
        }

        // 2. 스토리
        if let enhancedStory = enhancement.story, let originalStory = record.travelStory {
            record.travelStory = mergeStory(enhanced: enhancedStory, original: originalStory)
            logger.info("✨ [Merge/Record] 스토리 교체 완료")
        }

        // 3. 인사이트
        if let enhancedInsights = enhancement.insights, !enhancedInsights.isEmpty {
            record.insights = mergeInsights(enhanced: enhancedInsights, originals: record.insights)
            logger.info("✨ [Merge/Record] 인사이트 교체: \(enhancedInsights.count)개")
        }

        // 4. 여행 점수 요약
        if let summary = enhancement.tripScoreSummary, !summary.isEmpty,
           let originalScore = record.tripScore {
            record.tripScore = MomentScoreService.TripOverallScore(
                averageScore: originalScore.averageScore,
                peakMomentScore: originalScore.peakMomentScore,
                totalBadges: originalScore.totalBadges,
                tripGrade: originalScore.tripGrade,
                summary: summary
            )
            logger.info("✨ [Merge/Record] 여행 점수 요약 교체")
        }

        // 5. TravelDNA 설명
        if let dnaDesc = enhancement.travelDNADescription, !dnaDesc.isEmpty {
            record.aiEnhancedDNADescription = dnaDesc
            logger.info("✨ [Merge/Record] TravelDNA 설명 교체")
        }

        // 6. 사실 보정 (corrections) → TravelRecord의 장소에 반영
        if let corrections = enhancement.corrections, !corrections.isEmpty {
            applyCorrections(corrections, to: record)
        }

        // AI 상태 업데이트
        record.isAIEnhanced = true
        record.aiEnhancedAt = Date()
        record.updatedAt = Date()
    }

    // MARK: - Private: Prompt Building

    private static func buildSystemPrompt() -> String {
        """
        여행 기록 편집자. 온디바이스 분석의 사실 데이터를 보정하고 약간의 감성을 추가.

        역할:
        1. 사실 보정: 사진(첨부 시)/GPS/시간 정보를 보고 온디바이스 분석 오류 교정
           - 활동 유형 오분류 (예: 카페→음식점) → corrections에 기재
           - 장면 분류 오인식 → corrections에 기재
        2. 감성 추가: 보정된 사실 위에 짧은 감성 한두 문장 추가

        원칙:
        1. 팩트 70% + 감성 30% 비율 유지
        2. 각 항목 1~2문장, 짧고 간결하게
        3. 장소명, 시간, 거리, 수치는 절대 변경 금지 (보정 필요 시 corrections에 기재)
        4. 입력에 없는 사실을 지어내지 않음 (사진에 보이는 것만 근거)
        5. 사진이 첨부된 경우 사진의 실제 모습과 분위기를 우선시
        6. 한국어로 작성
        7. 반드시 유효한 JSON으로만 응답

        길이 가이드:
        - title: 15자 이내
        - story.opening: 1~2문장 (40~80자)
        - story.chapters[].content: 1~2문장 (40~80자)
        - story.climax: 1문장 (30~60자)
        - story.closing: 1문장 (30~60자)
        - story.tagline: 15~25자
        - insights[].description: 1문장 (30~60자)
        - travelDNADescription: 1~2문장 (40~80자)
        - tripScoreSummary: 1문장 (30~60자)
        """
    }

    private static func buildUserPrompt(from input: AIEnhancementInput) -> String {
        var parts: [String] = []

        // 기본 정보
        parts.append("""
        [여행 기본 정보]
        제목: \(input.title)
        기간: \(input.startDate) ~ \(input.endDate)
        총 이동 거리: \(String(format: "%.1f", input.totalDistance))km
        촬영 사진: \(input.photoCount)장
        방문 장소: \(input.places.count)곳
        """)

        // 장소 상세
        var placeParts: [String] = []
        for (i, place) in input.places.enumerated() {
            var desc = "\(i + 1). \(place.visitTime) \(place.name) (\(place.activityType))"
            if let duration = place.durationMinutes {
                desc += " \(duration)분 체류"
            }
            if let scene = place.sceneCategory {
                desc += " [\(scene)]"
            }
            if let score = place.momentScore, let grade = place.momentGrade {
                desc += " 점수:\(score)(\(grade))"
            }
            if !place.badges.isEmpty {
                desc += " 배지:\(place.badges.joined(separator: ","))"
            }
            placeParts.append(desc)
        }
        parts.append("[방문 장소]\n\(placeParts.joined(separator: "\n"))")

        // 스토리 컨텍스트
        if let story = input.storyContext {
            var storyPart = """
            [현재 스토리 - 분위기: \(story.mood)]
            제목: \(story.currentTitle)
            오프닝: \(story.currentOpening)
            """

            // 토큰 최적화: 8개 초과 시 상위 7개만, 나머지 요약
            let maxChapters = 7
            let chaptersToInclude = story.currentChapters.prefix(maxChapters)
            for chapter in chaptersToInclude {
                storyPart += "\n챕터[\(chapter.placeName)]: \(chapter.currentContent)"
            }
            if story.currentChapters.count > maxChapters {
                let remaining = story.currentChapters.count - maxChapters
                storyPart += "\n(외 \(remaining)곳 생략)"
            }

            storyPart += "\n클라이맥스: \(story.currentClimax)"
            storyPart += "\n엔딩: \(story.currentClosing)"
            storyPart += "\n태그라인: \(story.currentTagline)"
            parts.append(storyPart)
        }

        // 인사이트
        if !input.insights.isEmpty {
            var insightPart = "[현재 인사이트]"
            for insight in input.insights {
                insightPart += "\n- [\(insight.type)] \(insight.currentTitle): \(insight.currentDescription)"
                if let suggestion = insight.currentActionSuggestion {
                    insightPart += " → \(suggestion)"
                }
            }
            parts.append(insightPart)
        }

        // TravelDNA
        if let dna = input.travelDNA {
            var dnaPart = "[TravelDNA]"
            dnaPart += "\n유형: \(dna.primaryType)"
            if let secondary = dna.secondaryType {
                dnaPart += " / \(secondary)"
            }
            dnaPart += "\n특성: \(dna.traits.joined(separator: ", "))"
            dnaPart += "\n탐험:\(dna.explorationScore) 소셜:\(dna.socialScore) 문화:\(dna.cultureScore)"
            dnaPart += "\n현재 설명: \(dna.currentDescription)"
            parts.append(dnaPart)
        }

        // 여행 점수
        if let score = input.tripScore {
            parts.append("[여행 점수]\n평균: \(score.averageScore) 최고: \(score.peakMomentScore) 등급: \(score.tripGrade)\n현재 요약: \(score.currentSummary)")
        }

        // 순간 하이라이트
        if !input.momentScores.isEmpty {
            var highlightPart = "[순간 하이라이트]"
            for moment in input.momentScores {
                if !moment.currentHighlights.isEmpty {
                    highlightPart += "\n\(moment.placeName)(\(moment.grade)): \(moment.currentHighlights.joined(separator: ", "))"
                }
            }
            parts.append(highlightPart)
        }

        // JSON 응답 스키마
        parts.append("""
        [응답 형식 - JSON]
        {
          "enhancedTitle": "다듬어진 제목",
          "story": {
            "title": "스토리 제목",
            "opening": "사실+감성 오프닝",
            "chapters": [{"placeName": "장소명", "content": "사실+감성 챕터"}],
            "climax": "하이라이트",
            "closing": "마무리",
            "tagline": "한줄 요약"
          },
          "insights": [{"type": "인사이트타입", "title": "제목", "description": "설명"}],
          "tripScoreSummary": "여행 점수 요약",
          "momentHighlights": [{"placeName": "장소명", "highlights": ["하이라이트"]}],
          "travelDNADescription": "여행 DNA 설명",
          "corrections": [{"placeName": "장소명", "correctedActivityType": "보정된 활동유형", "correctedSceneCategory": "보정된 장면분류", "note": "보정 이유"}]
        }
        corrections는 온디바이스 분석이 틀린 경우에만 포함. 보정할 것이 없으면 빈 배열 또는 생략.
        """)

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Private: Response Parsing

    private static func parseResponse(_ response: String) throws -> AIEnhancementResult {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            logger.error("✨ [Parse] JSON 문자열 → Data 변환 실패")
            throw AIServiceError.decodingError
        }

        do {
            let result = try JSONDecoder().decode(AIEnhancementResult.self, from: data)
            return result
        } catch {
            logger.error("✨ [Parse] JSON 디코딩 실패: \(error.localizedDescription)")
            logger.error("✨ [Parse] 원본 응답 (처음 500자): \(String(jsonString.prefix(500)))")
            throw AIServiceError.decodingError
        }
    }

    /// AI 응답에서 JSON 추출
    /// 마크다운 코드블록 제거, { } 사이 내용 추출
    private static func extractJSON(from response: String) -> String {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // ```json ... ``` 또는 ``` ... ``` 코드블록 제거
        if let codeBlockRange = text.range(of: "```json", options: .caseInsensitive) {
            text = String(text[codeBlockRange.upperBound...])
            if let endRange = text.range(of: "```") {
                text = String(text[..<endRange.lowerBound])
            }
        } else if let codeBlockRange = text.range(of: "```") {
            text = String(text[codeBlockRange.upperBound...])
            if let endRange = text.range(of: "```") {
                text = String(text[..<endRange.lowerBound])
            }
        }

        // { } 사이 내용 추출
        if let firstBrace = text.firstIndex(of: "{"),
           let lastBrace = text.lastIndex(of: "}") {
            text = String(text[firstBrace...lastBrace])
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private: Merge Helpers

    /// 스토리 머지: enhanced 값이 있으면 교체, 없으면 원본 유지
    /// mood, keywords는 항상 원본 유지 (AI가 변경하지 않음)
    private static func mergeStory(
        enhanced: AIEnhancementResult.EnhancedStory,
        original: StoryWeavingService.TravelStory
    ) -> StoryWeavingService.TravelStory {

        // 챕터 머지: placeName으로 매칭
        let mergedChapters: [StoryWeavingService.StoryChapter] = original.chapters.map { originalChapter in
            if let enhancedChapter = enhanced.chapters?.first(where: { $0.placeName == originalChapter.placeName }),
               !enhancedChapter.content.isEmpty {
                return StoryWeavingService.StoryChapter(
                    title: originalChapter.title,
                    content: enhancedChapter.content,
                    placeName: originalChapter.placeName,
                    emoji: originalChapter.emoji,
                    momentScore: originalChapter.momentScore
                )
            }
            return originalChapter
        }

        return StoryWeavingService.TravelStory(
            title: (enhanced.title?.isEmpty == false) ? enhanced.title! : original.title,
            opening: (enhanced.opening?.isEmpty == false) ? enhanced.opening! : original.opening,
            chapters: mergedChapters,
            climax: (enhanced.climax?.isEmpty == false) ? enhanced.climax! : original.climax,
            closing: (enhanced.closing?.isEmpty == false) ? enhanced.closing! : original.closing,
            tagline: (enhanced.tagline?.isEmpty == false) ? enhanced.tagline! : original.tagline,
            mood: original.mood,
            keywords: original.keywords
        )
    }

    /// 인사이트 머지: type으로 매칭, emoji/importance/relatedData는 원본 유지
    private static func mergeInsights(
        enhanced: [AIEnhancementResult.EnhancedInsight],
        originals: [InsightEngine.TravelInsight]
    ) -> [InsightEngine.TravelInsight] {
        originals.map { original in
            if let enhancedInsight = enhanced.first(where: { $0.type == original.type.rawValue }) {
                return InsightEngine.TravelInsight(
                    id: original.id,
                    type: original.type,
                    title: (enhancedInsight.title?.isEmpty == false) ? enhancedInsight.title! : original.title,
                    description: (enhancedInsight.description?.isEmpty == false) ? enhancedInsight.description! : original.description,
                    emoji: original.emoji,
                    importance: original.importance,
                    relatedData: original.relatedData,
                    actionSuggestion: enhancedInsight.actionSuggestion ?? original.actionSuggestion
                )
            }
            return original
        }
    }

    /// MomentScore 하이라이트 머지: placeName으로 매칭
    /// 점수, 등급, 배지 등 수치는 원본 유지, highlights 텍스트만 교체
    private static func mergeMomentHighlights(
        enhanced: [AIEnhancementResult.EnhancedMomentHighlight],
        originals: [MomentScoreService.MomentScore],
        places: [PlaceCluster]
    ) -> [MomentScoreService.MomentScore] {
        guard originals.count == places.count else { return originals }

        return originals.enumerated().map { index, original in
            let placeName = places[index].name
            if let enhancedHighlight = enhanced.first(where: { $0.placeName == placeName }),
               !enhancedHighlight.highlights.isEmpty {
                return MomentScoreService.MomentScore(
                    totalScore: original.totalScore,
                    grade: original.grade,
                    components: original.components,
                    highlights: enhancedHighlight.highlights,
                    specialBadges: original.specialBadges
                )
            }
            return original
        }
    }

    // MARK: - Corrections Merge

    /// AI 사실 보정을 AnalysisResult에 반영
    /// placeName으로 매칭하여 activityType, sceneCategory 교체
    private static func applyCorrections(
        _ corrections: [AIEnhancementResult.PlaceCorrection],
        to result: inout AnalysisResult
    ) {
        for correction in corrections {
            guard let index = result.places.firstIndex(where: { $0.name == correction.placeName }) else {
                logger.info("✨ [Corrections] 장소 미매칭: \(correction.placeName)")
                continue
            }

            if let correctedActivity = correction.correctedActivityType,
               let activityType = ActivityType(rawValue: correctedActivity) {
                let original = result.places[index].activityType.rawValue
                result.places[index].activityType = activityType
                logger.info("✨ [Corrections] \(correction.placeName) 활동 보정: \(original) → \(correctedActivity)")
            }

            if let correctedScene = correction.correctedSceneCategory,
               let sceneCategory = VisionAnalysisService.SceneCategory(rawValue: correctedScene) {
                let original = result.places[index].sceneCategory?.rawValue ?? "nil"
                result.places[index].sceneCategory = sceneCategory
                logger.info("✨ [Corrections] \(correction.placeName) 장면 보정: \(original) → \(correctedScene)")
            }

            if let note = correction.note {
                logger.info("✨ [Corrections] \(correction.placeName) 보정 이유: \(note)")
            }
        }
    }

    /// AI 사실 보정을 TravelRecord에 반영
    private static func applyCorrections(
        _ corrections: [AIEnhancementResult.PlaceCorrection],
        to record: TravelRecord
    ) {
        for correction in corrections {
            // TravelRecord → days → places에서 이름으로 검색
            for day in record.days {
                if let place = day.places.first(where: { $0.name == correction.placeName }) {
                    if let correctedActivity = correction.correctedActivityType {
                        let original = place.activityLabel
                        place.activityLabel = correctedActivity
                        logger.info("✨ [Corrections/Record] \(correction.placeName) 활동 보정: \(original) → \(correctedActivity)")
                    }
                    if let note = correction.note {
                        logger.info("✨ [Corrections/Record] \(correction.placeName) 보정 이유: \(note)")
                    }
                }
            }
        }
    }

    // MARK: - Image Extraction (멀티모달)

    /// 각 장소의 대표 사진 1장씩 추출 (최대 8장)
    /// 320×320 리사이즈, JPEG 0.6 압축
    private static func extractRepresentativeImages(
        from places: [PlaceCluster],
        selectedAssets: [PHAsset]
    ) async -> [AIImageData] {
        var images: [AIImageData] = []
        let maxImages = 8
        let targetSize = CGSize(width: 320, height: 320)

        // 각 장소의 첫 번째 사진의 localIdentifier 수집
        var assetIdsToFetch: [(placeIndex: Int, assetId: String)] = []
        for (index, place) in places.prefix(maxImages).enumerated() {
            if let firstPhoto = place.photos.first {
                assetIdsToFetch.append((index, firstPhoto.localIdentifier))
            }
        }

        // PHAsset에서 이미지 추출
        for item in assetIdsToFetch {
            if let asset = selectedAssets.first(where: { $0.localIdentifier == item.assetId }) {
                if let imageData = await loadImageData(from: asset, targetSize: targetSize) {
                    images.append(AIImageData(data: imageData, mimeType: "image/jpeg"))
                }
            }
        }

        return images
    }

    /// PHAsset에서 JPEG 이미지 데이터 추출
    private static func loadImageData(from asset: PHAsset, targetSize: CGSize) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .exact
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard let image = image else {
                    continuation.resume(returning: nil)
                    return
                }
                let data = image.jpegData(compressionQuality: 0.6)
                continuation.resume(returning: data)
            }
        }
    }
}
