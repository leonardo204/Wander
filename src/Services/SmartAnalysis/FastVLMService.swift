import Foundation
import Photos
import UIKit
import os.log

#if canImport(CoreML)
import CoreML
#endif

private let logger = Logger(subsystem: "com.zerolive.wander", category: "FastVLM")

/// iOS 18.2+ FastVLM 기반 고급 이미지 분석 서비스
/// Vision Language Model을 활용한 자연어 장면 설명 생성
@available(iOS 18.2, *)
@MainActor
class FastVLMService {

    // MARK: - Scene Description Result

    struct SceneDescription {
        let shortDescription: String      // 짧은 설명 (1문장)
        let detailedDescription: String   // 상세 설명 (2-3문장)
        let mood: TravelMood              // 분위기
        let keywords: [String]            // 키워드 (최대 5개)
        let suggestedActivity: String     // 추천 활동
        let confidence: Float             // 신뢰도
    }

    // MARK: - Travel Mood

    enum TravelMood: String, CaseIterable {
        case peaceful       // 평화로운
        case adventurous    // 모험적인
        case romantic       // 로맨틱한
        case energetic      // 활기찬
        case relaxing       // 여유로운
        case cultural       // 문화적인
        case nostalgic      // 향수적인
        case joyful         // 즐거운

        var emoji: String {
            switch self {
            case .peaceful: return "🌿"
            case .adventurous: return "🏔️"
            case .romantic: return "💕"
            case .energetic: return "⚡"
            case .relaxing: return "🌊"
            case .cultural: return "🏛️"
            case .nostalgic: return "📷"
            case .joyful: return "🎉"
            }
        }

        var koreanName: String {
            switch self {
            case .peaceful: return "평화로운"
            case .adventurous: return "모험적인"
            case .romantic: return "로맨틱한"
            case .energetic: return "활기찬"
            case .relaxing: return "여유로운"
            case .cultural: return "문화적인"
            case .nostalgic: return "추억이 깃든"
            case .joyful: return "즐거운"
            }
        }
    }

    // MARK: - Image Manager

    private let imageManager = PHCachingImageManager()

    // MARK: - Analyze Photo with VLM

    /// FastVLM을 사용한 사진 분석
    /// - Parameter asset: 분석할 PHAsset
    /// - Returns: 장면 설명 결과
    func analyzePhoto(_ asset: PHAsset) async -> SceneDescription? {
        guard let image = await loadImage(from: asset) else {
            logger.warning("🤖 [FastVLM] 이미지 로드 실패")
            return nil
        }

        return await analyzeImage(image)
    }

    /// UIImage 분석
    func analyzeImage(_ image: UIImage) async -> SceneDescription? {
        logger.info("🤖 [FastVLM] 이미지 분석 시작")

        // iOS 18.2+ Foundation Models API 사용
        // Note: 실제 FastVLM API가 공개되면 여기에 구현
        // 현재는 Vision Framework + 휴리스틱 기반 fallback

        // Vision 분류 결과를 기반으로 설명 생성
        let visionService = VisionAnalysisService()
        let classifications = await visionService.classifyScene(image: image)

        guard let topClassification = classifications.first else {
            return nil
        }

        // 분류 결과를 기반으로 자연어 설명 생성
        let description = generateDescription(from: classifications)

        logger.info("🤖 [FastVLM] 분석 완료: \(description.shortDescription)")

        return description
    }

    /// 클러스터 전체 분석 (대표 사진 + 종합)
    func analyzeCluster(assets: [PHAsset]) async -> ClusterAnalysis? {
        guard !assets.isEmpty else { return nil }

        logger.info("🤖 [FastVLM] 클러스터 분석 시작 - \(assets.count)장")

        // 대표 사진 3장 선택 (처음, 중간, 마지막)
        let samples = sampleAssets(from: assets, count: 3)
        var descriptions: [SceneDescription] = []

        for asset in samples {
            if let desc = await analyzePhoto(asset) {
                descriptions.append(desc)
            }
        }

        guard !descriptions.isEmpty else { return nil }

        // 종합 분석
        let synthesized = synthesizeDescriptions(descriptions)

        logger.info("🤖 [FastVLM] 클러스터 분석 완료")

        return ClusterAnalysis(
            descriptions: descriptions,
            synthesizedDescription: synthesized.detailedDescription,
            dominantMood: synthesized.mood,
            allKeywords: Array(Set(descriptions.flatMap { $0.keywords })).prefix(7).map { $0 },
            highlightMoment: findHighlightMoment(from: descriptions)
        )
    }

    // MARK: - Generate Description from Classifications

    private func generateDescription(from classifications: [VisionAnalysisService.SceneClassification]) -> SceneDescription {
        guard let top = classifications.first else {
            return defaultDescription()
        }

        let category = top.category
        let mood = inferMood(from: category)
        let keywords = generateKeywords(from: classifications)

        // 카테고리별 설명 템플릿
        let (short, detailed) = generateTemplateDescription(category: category, mood: mood)

        return SceneDescription(
            shortDescription: short,
            detailedDescription: detailed,
            mood: mood,
            keywords: keywords,
            suggestedActivity: suggestActivity(for: category),
            confidence: top.confidence
        )
    }

    private func generateTemplateDescription(
        category: VisionAnalysisService.SceneCategory,
        mood: TravelMood
    ) -> (String, String) {
        switch category {
        case .beach:
            return (
                "푸른 바다가 펼쳐진 해변",
                "파도 소리와 함께 여유로운 시간을 보내는 해변가입니다. 따스한 햇살 아래 특별한 순간을 담았습니다."
            )
        case .mountain:
            return (
                "웅장한 산의 품에서",
                "자연의 위대함을 느낄 수 있는 산 속 풍경입니다. 맑은 공기와 함께 힐링의 시간을 보냈습니다."
            )
        case .cafe:
            return (
                "향기로운 커피 한 잔의 여유",
                "아늑한 분위기의 카페에서 여유로운 시간을 보내고 있습니다. 일상에서 벗어난 작은 행복입니다."
            )
        case .restaurant, .food:
            return (
                "맛있는 음식과 함께한 순간",
                "현지의 맛을 경험하는 특별한 식사 시간입니다. 여행의 또 다른 즐거움을 만끽했습니다."
            )
        case .museum:
            return (
                "역사와 예술이 숨쉬는 공간",
                "문화와 예술을 감상하며 지적 호기심을 채우는 시간입니다. 새로운 영감을 얻었습니다."
            )
        case .temple:
            return (
                "고요한 사찰의 평화",
                "전통의 멋과 고요함이 있는 사찰에서 마음의 평화를 찾았습니다."
            )
        case .park, .nature:
            return (
                "자연 속 힐링의 시간",
                "푸른 녹음 사이로 산책하며 자연과 하나되는 시간입니다. 일상의 스트레스가 사라집니다."
            )
        case .city:
            return (
                "도시의 활기찬 에너지",
                "도시 특유의 활력과 다양한 볼거리가 가득한 거리입니다. 새로운 발견의 연속이었습니다."
            )
        case .shopping:
            return (
                "쇼핑의 즐거움",
                "다양한 상품들 사이에서 특별한 것을 찾는 즐거움입니다. 여행의 기념품을 발견했습니다."
            )
        case .hotel:
            return (
                "편안한 휴식의 공간",
                "여행의 피로를 풀 수 있는 아늑한 숙소입니다. 내일을 위한 충전의 시간입니다."
            )
        case .airport:
            return (
                "설레는 여행의 시작",
                "새로운 여정의 시작점인 공항입니다. 곧 펼쳐질 모험에 대한 기대감이 가득합니다."
            )
        case .landmark:
            return (
                "랜드마크에서의 특별한 순간",
                "이 여행을 상징하는 특별한 장소에서의 기념 사진입니다. 오래 기억될 순간입니다."
            )
        case .people:
            return (
                "함께한 소중한 사람들",
                "여행을 더욱 특별하게 만들어준 사람들과 함께한 순간입니다."
            )
        default:
            return (
                "여행 중 발견한 순간",
                "여행 중 우연히 마주한 특별한 풍경입니다. 소소하지만 의미있는 순간을 담았습니다."
            )
        }
    }

    // MARK: - Mood Inference

    private func inferMood(from category: VisionAnalysisService.SceneCategory) -> TravelMood {
        switch category {
        case .beach, .nature, .park:
            return .relaxing
        case .mountain:
            return .adventurous
        case .cafe:
            return .peaceful
        case .restaurant, .food:
            return .joyful
        case .museum, .temple:
            return .cultural
        case .city, .shopping:
            return .energetic
        case .landmark:
            return .nostalgic
        default:
            return .peaceful
        }
    }

    // MARK: - Keywords Generation

    private func generateKeywords(from classifications: [VisionAnalysisService.SceneClassification]) -> [String] {
        var keywords: [String] = []

        for classification in classifications.prefix(3) {
            keywords.append(classification.koreanLabel)

            // 카테고리별 추가 키워드
            switch classification.category {
            case .beach:
                keywords.append(contentsOf: ["바다", "휴양"])
            case .mountain:
                keywords.append(contentsOf: ["자연", "트레킹"])
            case .cafe:
                keywords.append(contentsOf: ["커피", "여유"])
            case .food, .restaurant:
                keywords.append(contentsOf: ["맛집", "미식"])
            case .museum:
                keywords.append(contentsOf: ["문화", "예술"])
            case .temple:
                keywords.append(contentsOf: ["전통", "힐링"])
            default:
                break
            }
        }

        return Array(Set(keywords)).prefix(5).map { $0 }
    }

    // MARK: - Activity Suggestion

    private func suggestActivity(for category: VisionAnalysisService.SceneCategory) -> String {
        switch category {
        case .beach: return "해변 산책, 수영, 일몰 감상"
        case .mountain: return "등산, 트레킹, 자연 감상"
        case .cafe: return "커피 타임, 디저트 즐기기"
        case .restaurant, .food: return "현지 맛집 탐방"
        case .museum: return "전시 관람, 문화 체험"
        case .temple: return "사찰 순례, 명상"
        case .park, .nature: return "산책, 피크닉"
        case .city: return "거리 탐방, 사진 촬영"
        case .shopping: return "쇼핑, 기념품 구매"
        default: return "자유 시간"
        }
    }

    // MARK: - Synthesis

    private func synthesizeDescriptions(_ descriptions: [SceneDescription]) -> SceneDescription {
        // 가장 많이 나온 무드 선택
        let moodCounts = Dictionary(grouping: descriptions, by: { $0.mood })
        let dominantMood = moodCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .peaceful

        // 키워드 합치기
        let allKeywords = Array(Set(descriptions.flatMap { $0.keywords })).prefix(5).map { $0 }

        // 종합 설명 생성
        let synthesizedDetail = descriptions.map { $0.shortDescription }.joined(separator: " ")

        return SceneDescription(
            shortDescription: descriptions.first?.shortDescription ?? "",
            detailedDescription: synthesizedDetail,
            mood: dominantMood,
            keywords: allKeywords,
            suggestedActivity: descriptions.first?.suggestedActivity ?? "",
            confidence: descriptions.map { $0.confidence }.reduce(0, +) / Float(descriptions.count)
        )
    }

    private func findHighlightMoment(from descriptions: [SceneDescription]) -> String {
        // 가장 신뢰도 높은 설명을 하이라이트로
        if let best = descriptions.max(by: { $0.confidence < $1.confidence }) {
            return best.shortDescription
        }
        return descriptions.first?.shortDescription ?? ""
    }

    // MARK: - Helper

    private func loadImage(from asset: PHAsset, targetSize: CGSize = CGSize(width: 512, height: 512)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private func sampleAssets(from assets: [PHAsset], count: Int) -> [PHAsset] {
        guard assets.count > count else { return assets }

        var samples: [PHAsset] = []
        let step = Double(assets.count - 1) / Double(count - 1)

        for i in 0..<count {
            let index = Int(Double(i) * step)
            samples.append(assets[index])
        }

        return samples
    }

    private func defaultDescription() -> SceneDescription {
        SceneDescription(
            shortDescription: "여행의 한 순간",
            detailedDescription: "여행 중 담은 특별한 순간입니다.",
            mood: .peaceful,
            keywords: ["여행", "추억"],
            suggestedActivity: "자유 시간",
            confidence: 0.5
        )
    }
}

// MARK: - Cluster Analysis Result

@available(iOS 18.2, *)
extension FastVLMService {
    struct ClusterAnalysis {
        let descriptions: [SceneDescription]
        let synthesizedDescription: String
        let dominantMood: TravelMood
        let allKeywords: [String]
        let highlightMoment: String
    }
}
