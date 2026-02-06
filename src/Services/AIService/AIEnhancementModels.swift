import Foundation

// MARK: - AI Enhancement Input

/// AI에 전달할 분석 데이터 전체
/// AnalysisResult에서 텍스트 관련 데이터를 추출하여 구성
struct AIEnhancementInput: Codable {
    let title: String
    let startDate: String
    let endDate: String
    let totalDistance: Double
    let photoCount: Int

    let places: [PlaceInput]
    let storyContext: StoryContextInput?
    let insights: [InsightInput]
    let travelDNA: TravelDNAInput?
    let tripScore: TripScoreInput?
    let momentScores: [MomentScoreInput]

    struct PlaceInput: Codable {
        let name: String
        let address: String
        let activityType: String
        let visitTime: String
        let photoCount: Int
        let durationMinutes: Int?
        let sceneCategory: String?
        let badges: [String]
        let momentScore: Int?
        let momentGrade: String?
        let highlights: [String]
    }

    struct StoryContextInput: Codable {
        let mood: String
        let currentTitle: String
        let currentOpening: String
        let currentChapters: [ChapterInput]
        let currentClimax: String
        let currentClosing: String
        let currentTagline: String
    }

    struct ChapterInput: Codable {
        let placeName: String
        let currentContent: String
        let emoji: String
    }

    struct InsightInput: Codable {
        let type: String
        let currentTitle: String
        let currentDescription: String
        let currentActionSuggestion: String?
        let emoji: String
        let importance: Int
    }

    struct TravelDNAInput: Codable {
        let primaryType: String
        let secondaryType: String?
        let traits: [String]
        let explorationScore: Int
        let socialScore: Int
        let cultureScore: Int
        let dnaCode: String
        let currentDescription: String
    }

    struct TripScoreInput: Codable {
        let averageScore: Int
        let peakMomentScore: Int
        let tripGrade: String
        let currentSummary: String
    }

    struct MomentScoreInput: Codable {
        let placeName: String
        let totalScore: Int
        let grade: String
        let currentHighlights: [String]
    }
}

// MARK: - AI Enhancement Result

/// AI가 반환한 다듬어진 텍스트
/// 모든 필드가 Optional → 부분 실패 시 원본 유지
struct AIEnhancementResult: Codable {
    let enhancedTitle: String?
    let story: EnhancedStory?
    let insights: [EnhancedInsight]?
    let tripScoreSummary: String?
    let momentHighlights: [EnhancedMomentHighlight]?
    let travelDNADescription: String?
    let corrections: [PlaceCorrection]?  // AI 사실 보정

    struct EnhancedStory: Codable {
        let title: String?
        let opening: String?
        let chapters: [EnhancedChapter]?
        let climax: String?
        let closing: String?
        let tagline: String?
    }

    struct EnhancedChapter: Codable {
        let placeName: String
        let content: String
    }

    struct EnhancedInsight: Codable {
        let type: String
        let title: String?
        let description: String?
        let actionSuggestion: String?
    }

    struct EnhancedMomentHighlight: Codable {
        let placeName: String
        let highlights: [String]
    }

    /// AI가 사진/GPS/날짜를 보고 온디바이스 분석의 오류를 보정한 결과
    struct PlaceCorrection: Codable {
        let placeName: String
        let correctedActivityType: String?   // 보정된 활동 유형
        let correctedSceneCategory: String?  // 보정된 장면 분류
        let note: String?                    // 보정 이유 (로그용)
    }
}
