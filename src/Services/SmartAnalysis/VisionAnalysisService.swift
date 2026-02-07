import Foundation
import Vision
import Photos
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "VisionAnalysis")

/// Vision Framework 기반 이미지 장면 분류 서비스
/// iOS 17+: VNClassifyImageRequest (1,303개 카테고리)
/// iOS 18+: 추가 고급 분석 기능 (예정)
@MainActor
class VisionAnalysisService {

    // MARK: - Scene Classification Result

    struct SceneClassification {
        let identifier: String      // Vision 분류 식별자
        let confidence: Float       // 신뢰도 (0.0 ~ 1.0)
        let category: SceneCategory // 앱 내부 카테고리 매핑
        let koreanLabel: String     // 한국어 라벨
    }

    // MARK: - Scene Category (앱 내부 카테고리)

    enum SceneCategory: String, CaseIterable {
        case cafe           // 카페, 커피숍
        case restaurant     // 식당, 음식점
        case beach          // 해변, 바다
        case mountain       // 산, 자연
        case park           // 공원, 정원
        case museum         // 박물관, 미술관
        case shopping       // 쇼핑몰, 시장
        case airport        // 공항
        case hotel          // 호텔, 숙소
        case temple         // 사찰, 절
        case city           // 도시, 거리
        case nature         // 자연 풍경
        case food           // 음식 사진
        case people         // 인물 사진
        case landmark       // 랜드마크
        case unknown        // 분류 불가

        var emoji: String {
            switch self {
            case .cafe: return "☕"
            case .restaurant: return "🍽️"
            case .beach: return "🏖️"
            case .mountain: return "⛰️"
            case .park: return "🌳"
            case .museum: return "🏛️"
            case .shopping: return "🛍️"
            case .airport: return "✈️"
            case .hotel: return "🏨"
            case .temple: return "⛩️"
            case .city: return "🏙️"
            case .nature: return "🌿"
            case .food: return "🍜"
            case .people: return "👥"
            case .landmark: return "🗼"
            case .unknown: return "📍"
            }
        }

        var koreanName: String {
            switch self {
            case .cafe: return "카페"
            case .restaurant: return "음식점"
            case .beach: return "해변"
            case .mountain: return "산"
            case .park: return "공원"
            case .museum: return "박물관"
            case .shopping: return "쇼핑"
            case .airport: return "공항"
            case .hotel: return "숙소"
            case .temple: return "사찰"
            case .city: return "도시"
            case .nature: return "자연"
            case .food: return "음식"
            case .people: return "인물"
            case .landmark: return "명소"
            case .unknown: return "장소"
            }
        }

        /// ActivityType으로 변환
        var toActivityType: ActivityType {
            switch self {
            case .cafe: return .cafe
            case .restaurant, .food: return .restaurant
            case .beach: return .beach
            case .mountain, .nature, .park: return .mountain
            case .museum, .temple, .landmark: return .culture
            case .shopping: return .shopping
            case .airport: return .airport
            default: return .tourist
            }
        }
    }

    // MARK: - Vision 분류자 → 앱 카테고리 매핑

    /// Vision Framework의 1,303개 분류자를 앱 카테고리로 매핑
    private static let categoryMapping: [String: SceneCategory] = [
        // 카페/커피
        "coffee_shop": .cafe,
        "coffeehouse": .cafe,
        "café": .cafe,
        "bakery": .cafe,
        "tea_house": .cafe,

        // 식당/음식점 (장소)
        "restaurant": .restaurant,
        "dining_room": .restaurant,
        "kitchen": .restaurant,
        "pizzeria": .restaurant,
        "sushi_bar": .restaurant,
        "food_court": .restaurant,
        "banquet_hall": .restaurant,
        "bar": .restaurant,
        "pub": .restaurant,
        "bistro": .restaurant,
        "cafeteria": .restaurant,
        "diner": .restaurant,
        "fast_food_restaurant": .restaurant,
        "ramen_shop": .restaurant,
        "barbecue": .restaurant,
        "buffet": .restaurant,

        // 음식 (Food - 일반)
        "food": .food,
        "meal": .food,
        "dish": .food,
        "plate": .food,
        "bowl": .food,
        "cuisine": .food,

        // 한식/아시안
        "korean_food": .food,
        "kimchi": .food,
        "bibimbap": .food,
        "bulgogi": .food,
        "rice": .food,
        "fried_rice": .food,
        "noodle": .food,
        "ramen": .food,
        "udon": .food,
        "pho": .food,
        "pad_thai": .food,
        "dumpling": .food,
        "dim_sum": .food,
        "spring_roll": .food,
        "sushi": .food,
        "sashimi": .food,
        "tempura": .food,
        "teriyaki": .food,
        "bento": .food,
        "curry": .food,
        "soup": .food,
        "stew": .food,
        "hotpot": .food,
        "tofu": .food,

        // 양식
        "pizza": .food,
        "pasta": .food,
        "spaghetti": .food,
        "lasagna": .food,
        "burger": .food,
        "hamburger": .food,
        "cheeseburger": .food,
        "sandwich": .food,
        "hot_dog": .food,
        "french_fries": .food,
        "fries": .food,
        "steak": .food,
        "meat": .food,
        "beef": .food,
        "pork": .food,
        "chicken": .food,
        "fried_chicken": .food,
        "roast": .food,
        "grill": .food,
        "grilled_meat": .food,
        "salad": .food,
        "caesar_salad": .food,
        "omelette": .food,
        "egg": .food,
        "bacon": .food,
        "sausage": .food,
        "bread": .food,
        "toast": .food,
        "croissant": .food,
        "bagel": .food,
        "pancake": .food,
        "waffle": .food,
        "breakfast": .food,
        "brunch": .food,

        // 해산물
        "seafood": .food,
        "fish": .food,
        "salmon": .food,
        "tuna": .food,
        "shrimp": .food,
        "lobster": .food,
        "crab": .food,
        "oyster": .food,
        "mussel": .food,
        "clam": .food,
        "squid": .food,
        "octopus": .food,

        // 디저트/간식
        "dessert": .food,
        "cake": .food,
        "chocolate_cake": .food,
        "cheesecake": .food,
        "pie": .food,
        "tart": .food,
        "cookie": .food,
        "brownie": .food,
        "donut": .food,
        "doughnut": .food,
        "macaron": .food,
        "muffin": .food,
        "cupcake": .food,
        "ice_cream": .food,
        "gelato": .food,
        "frozen_yogurt": .food,
        "sundae": .food,
        "chocolate": .food,
        "candy": .food,
        "pudding": .food,
        "custard": .food,
        "cream": .food,
        "whipped_cream": .food,
        "fruit": .food,
        "apple": .food,
        "banana": .food,
        "orange": .food,
        "strawberry": .food,
        "watermelon": .food,
        "grape": .food,
        "mango": .food,

        // 음료
        "beverage": .food,
        "drink": .food,
        "coffee": .cafe,
        "espresso": .cafe,
        "latte": .cafe,
        "cappuccino": .cafe,
        "americano": .cafe,
        "tea": .cafe,
        "juice": .food,
        "smoothie": .food,
        "milkshake": .food,
        "cocktail": .food,
        "wine": .food,
        "beer": .food,
        "soda": .food,
        "water_bottle": .food,

        // 음식 관련 객체
        "dining_table": .restaurant,
        "table_setting": .restaurant,
        "chopsticks": .food,
        "fork": .food,
        "spoon": .food,
        "knife": .food,
        "cup": .food,
        "mug": .cafe,
        "glass": .food,
        "wine_glass": .food,
        "bottle": .food,

        // 해변/바다
        "beach": .beach,
        "coast": .beach,
        "seashore": .beach,
        "ocean": .beach,
        "sea": .beach,
        "swimming_pool": .beach,

        // 산/자연
        "mountain": .mountain,
        "mountain_path": .mountain,
        "mountain_snowy": .mountain,
        "valley": .mountain,
        "cliff": .mountain,
        "hiking": .mountain,
        "forest": .nature,
        "forest_path": .nature,
        "tree_farm": .nature,
        "bamboo_forest": .nature,
        "rainforest": .nature,
        "waterfall": .nature,
        "river": .nature,
        "lake": .nature,
        "pond": .nature,
        "field": .nature,
        "meadow": .nature,
        "flower_garden": .nature,

        // 공원/정원
        "park": .park,
        "botanical_garden": .park,
        "japanese_garden": .park,
        "zen_garden": .park,
        "playground": .park,
        "picnic_area": .park,

        // 박물관/문화
        "museum": .museum,
        "art_gallery": .museum,
        "art_museum": .museum,
        "exhibition_hall": .museum,
        "palace": .museum,
        "castle": .museum,
        "amphitheater": .museum,
        "theater": .museum,
        "concert_hall": .museum,
        "opera_house": .museum,

        // 쇼핑
        "shopping_mall": .shopping,
        "market": .shopping,
        "supermarket": .shopping,
        "convenience_store": .shopping,
        "department_store": .shopping,
        "clothing_store": .shopping,
        "bazaar": .shopping,

        // 공항/교통
        "airport": .airport,
        "airport_terminal": .airport,
        "airplane_cabin": .airport,
        "train_station": .airport,
        "subway_station": .airport,
        "bus_station": .airport,

        // 호텔/숙소
        "hotel": .hotel,
        "hotel_room": .hotel,
        "motel": .hotel,
        "bedroom": .hotel,
        "lobby": .hotel,

        // 사찰/종교
        "temple": .temple,
        "pagoda": .temple,
        "shrine": .temple,
        "church": .temple,
        "cathedral": .temple,
        "mosque": .temple,

        // 도시/거리
        "street": .city,
        "downtown": .city,
        "skyscraper": .city,
        "office_building": .city,
        "alley": .city,
        "crosswalk": .city,
        "bridge": .city,
        "plaza": .city,
        "square": .city,

        // 랜드마크
        "tower": .landmark,
        "lighthouse": .landmark,
        "monument": .landmark,
        "fountain": .landmark,
        "statue": .landmark,

        // 인물
        "person": .people,
        "people": .people,
        "crowd": .people,
        "selfie": .people,
    ]

    /// 한국어 라벨 매핑
    private static let koreanLabels: [String: String] = [
        "coffee_shop": "커피숍",
        "restaurant": "레스토랑",
        "beach": "해변",
        "mountain": "산",
        "forest": "숲",
        "park": "공원",
        "museum": "박물관",
        "temple": "사찰",
        "street": "거리",
        "hotel": "호텔",
        "airport": "공항",
        "tower": "타워",
        "food": "음식",
        // ... 필요시 추가
    ]

    // MARK: - Image Manager

    private let imageManager = PHCachingImageManager()

    // MARK: - Analyze Single Photo

    /// 단일 사진의 장면 분류
    /// - Parameter asset: 분석할 PHAsset
    /// - Returns: 상위 3개 분류 결과
    func classifyScene(for asset: PHAsset) async -> [SceneClassification] {
        guard let image = await loadImage(from: asset) else {
            logger.warning("✨ [Vision] 이미지 로드 실패: \(asset.localIdentifier.prefix(8))...")
            return []
        }

        return await classifyScene(image: image)
    }

    /// UIImage에서 장면 분류
    func classifyScene(image: UIImage) async -> [SceneClassification] {
        guard let cgImage = image.cgImage else {
            logger.warning("✨ [Vision] CGImage 변환 실패")
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    logger.error("✨ [Vision] 분류 에러: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // 상위 10개 결과 로깅 (디버깅용)
                let top10 = results.prefix(10)
                logger.info("✨ [Vision] 원본 상위 10개: \(top10.map { "\($0.identifier)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", "))")

                // 상위 5개 결과 중 confidence 0.1 이상만 필터
                let topResults = results
                    .filter { $0.confidence >= 0.1 }
                    .prefix(5)
                    .map { observation -> SceneClassification in
                        let identifier = observation.identifier
                        let category = Self.categoryMapping[identifier] ?? .unknown
                        let koreanLabel = Self.koreanLabels[identifier] ?? category.koreanName

                        // 매핑 안된 식별자 경고
                        if category == .unknown {
                            logger.warning("✨ [Vision] 매핑 안됨: '\(identifier)' (confidence: \(String(format: "%.2f", observation.confidence)))")
                        }

                        return SceneClassification(
                            identifier: identifier,
                            confidence: observation.confidence,
                            category: category,
                            koreanLabel: koreanLabel
                        )
                    }

                logger.info("✨ [Vision] 분류 결과: \(topResults.map { "\($0.identifier)→\($0.category.rawValue)" }.joined(separator: ", "))")
                continuation.resume(returning: Array(topResults))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                logger.error("✨ [Vision] 요청 수행 실패: \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Analyze Multiple Photos (Cluster)

    /// 클러스터 내 대표 사진들의 장면 분류 종합
    /// - Parameters:
    ///   - assets: 클러스터의 사진들
    ///   - sampleCount: 분석할 샘플 수 (기본 3장)
    /// - Returns: 종합된 장면 카테고리
    func analyzeCluster(assets: [PHAsset], sampleCount: Int = 3) async -> SceneCategory {
        guard !assets.isEmpty else { return .unknown }

        // 샘플링: 처음, 중간, 마지막에서 균등하게 선택
        let samples = sampleAssets(from: assets, count: sampleCount)

        var categoryVotes: [SceneCategory: Float] = [:]

        for asset in samples {
            let classifications = await classifyScene(for: asset)

            for classification in classifications {
                let weight = classification.confidence
                categoryVotes[classification.category, default: 0] += weight
            }
        }

        // 가장 많은 투표를 받은 카테고리 반환
        let topCategory = categoryVotes
            .sorted { $0.value > $1.value }
            .first?.key ?? .unknown

        logger.info("✨ [Vision] 클러스터 분석 결과: \(topCategory.koreanName) (투표: \(categoryVotes))")

        return topCategory
    }

    // MARK: - iOS 18+ Advanced Analysis

    /// iOS 18 이상에서 사용 가능한 고급 분석
    @available(iOS 18.0, *)
    func advancedAnalysis(for asset: PHAsset) async -> [String: Any] {
        var result: [String: Any] = [:]

        // 기본 장면 분류
        let classifications = await classifyScene(for: asset)
        result["classifications"] = classifications

        // TODO: iOS 18+ 전용 기능 추가
        // - FastVLM 통합 (가능한 경우)
        // - 더 상세한 장면 설명
        // - 감정/분위기 분석

        logger.info("✨ [Vision] iOS 18+ 고급 분석 완료")

        return result
    }

    // MARK: - Helper Methods

    /// PHAsset에서 UIImage 로드
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

    /// 균등 샘플링
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

    // MARK: - Keywords Extraction for SNS Sharing

    /// SNS 공유용 감성 키워드 매핑 (Vision 분류 → 감성 키워드)
    /// NOTE: Context별로 여행/일상 어감이 다르므로 travel/daily 두 세트 관리
    private static let travelKeywordMapping: [SceneCategory: [String]] = [
        .cafe: ["카페투어", "브런치", "커피타임", "감성카페", "힐링"],
        .restaurant: ["맛집탐방", "미식", "먹스타그램", "로컬푸드", "맛있는하루"],
        .beach: ["바다여행", "파도소리", "일몰", "해변산책", "시원한바람"],
        .mountain: ["등산", "트레킹", "자연힐링", "정상정복", "산책"],
        .park: ["피크닉", "공원산책", "여유", "힐링", "자연"],
        .museum: ["문화탐방", "전시관람", "예술", "역사여행", "감성"],
        .shopping: ["쇼핑", "힙스터", "빈티지", "플리마켓", "쇼핑투어"],
        .airport: ["여행시작", "설렘", "공항", "떠나요", "비행"],
        .hotel: ["호캉스", "휴식", "리프레시", "숙소", "힐링"],
        .temple: ["사찰여행", "고즈넉함", "힐링", "역사", "명상"],
        .city: ["도심탈출", "시티투어", "야경", "도시여행", "거리산책"],
        .nature: ["자연속으로", "힐링여행", "청량함", "숲속", "에코여행"],
        .food: ["먹방", "맛집", "음식스타그램", "미식여행", "맛있다"],
        .people: ["추억", "소중한시간", "함께", "우정", "행복"],
        .landmark: ["명소탐방", "인생샷", "포토스팟", "랜드마크", "여행"],
        .unknown: ["여행", "추억", "힐링", "소중한시간", "행복"]
    ]

    /// 일상/외출 컨텍스트용 키워드 매핑 (여행 관련 단어 제거)
    private static let dailyKeywordMapping: [SceneCategory: [String]] = [
        .cafe: ["카페", "브런치", "커피타임", "감성카페", "힐링"],
        .restaurant: ["맛집", "미식", "먹스타그램", "로컬푸드", "맛있는하루"],
        .beach: ["바다", "파도소리", "일몰", "해변산책", "시원한바람"],
        .mountain: ["등산", "트레킹", "자연힐링", "정상정복", "산책"],
        .park: ["피크닉", "공원산책", "여유", "힐링", "자연"],
        .museum: ["문화생활", "전시관람", "예술", "감성", "영감"],
        .shopping: ["쇼핑", "힙스터", "빈티지", "플리마켓", "득템"],
        .airport: ["공항", "설렘", "출발", "떠나요", "시작"],
        .hotel: ["휴식", "리프레시", "힐링", "쉼표", "여유"],
        .temple: ["고즈넉함", "힐링", "역사", "명상", "산책"],
        .city: ["거리산책", "도심", "야경", "산책", "나들이"],
        .nature: ["자연", "힐링", "청량함", "숲속", "산책"],
        .food: ["먹방", "맛집", "음식스타그램", "맛있다", "한끼"],
        .people: ["추억", "소중한시간", "함께", "우정", "행복"],
        .landmark: ["나들이", "인생샷", "포토스팟", "산책", "외출"],
        .unknown: ["일상", "추억", "힐링", "소중한시간", "행복"]
    ]

    /// Context에 따른 키워드 매핑 선택
    private static func keywordMapping(for context: TravelContext) -> [SceneCategory: [String]] {
        switch context {
        case .travel, .mixed:
            return travelKeywordMapping
        case .daily, .outing:
            return dailyKeywordMapping
        }
    }

    /// 여러 사진에서 SNS용 감성 키워드 추출
    /// - Parameters:
    ///   - assets: 분석할 PHAsset 배열
    ///   - maxKeywords: 최대 키워드 수 (기본 5개)
    ///   - context: 분석 컨텍스트 (일상/외출은 여행 키워드 제외)
    /// - Returns: 감성 키워드 배열 (중복 제거, 빈도순 정렬)
    func extractKeywords(from assets: [PHAsset], maxKeywords: Int = 5, context: TravelContext = .travel) async -> [String] {
        let isTravel = (context == .travel || context == .mixed)
        let defaultKeywords = isTravel ? ["여행", "추억", "힐링"] : ["일상", "추억", "힐링"]

        guard !assets.isEmpty else {
            return defaultKeywords
        }

        logger.info("✨ [Vision] 키워드 추출 시작 - \(assets.count)장 사진, context: \(context.displayName)")

        // 최대 5장 샘플링하여 분석
        let samples = sampleAssets(from: assets, count: min(assets.count, 5))

        var categoryVotes: [SceneCategory: Float] = [:]

        for asset in samples {
            let classifications = await classifyScene(for: asset)

            for classification in classifications {
                categoryVotes[classification.category, default: 0] += classification.confidence
            }
        }

        // 카테고리별 점수 정렬
        let allCategorySorted = categoryVotes.sorted { $0.value > $1.value }
        logger.info("✨ [Vision] 카테고리 점수: \(allCategorySorted.map { "\($0.key.rawValue)(\(String(format: "%.1f", $0.value)))" }.joined(separator: ", "))")

        let sortedCategories = allCategorySorted
            .prefix(3)
            .map { $0.key }

        logger.info("✨ [Vision] 상위 3개 카테고리: \(sortedCategories.map { $0.rawValue }.joined(separator: ", "))")

        // Context에 맞는 키워드 매핑 선택
        let mapping = Self.keywordMapping(for: context)

        // 키워드 수집 (상위 카테고리에서 키워드 선택)
        var keywordScores: [String: Float] = [:]

        for (index, category) in sortedCategories.enumerated() {
            let weight = Float(3 - index)  // 상위 카테고리에 높은 가중치
            if let categoryKeywords = mapping[category] {
                let selectedKeywords = Array(categoryKeywords.prefix(2))
                logger.info("✨ [Vision] \(category.rawValue) → 키워드: \(selectedKeywords.joined(separator: ", "))")
                for keyword in selectedKeywords {
                    keywordScores[keyword, default: 0] += weight
                }
            } else {
                logger.warning("✨ [Vision] \(category.rawValue) 카테고리에 매핑된 키워드 없음")
            }
        }

        // 점수순 정렬 후 상위 키워드 선택
        var keywords = keywordScores
            .sorted { $0.value > $1.value }
            .prefix(maxKeywords)
            .map { $0.key }

        // 최소 3개 보장 (context에 맞는 폴백)
        let fallbackKeywords = isTravel
            ? ["여행", "추억", "힐링", "소중한시간", "행복"]
            : ["일상", "추억", "힐링", "소중한시간", "행복"]
        let originalCount = keywords.count
        while keywords.count < 3 {
            for fallback in fallbackKeywords {
                if !keywords.contains(fallback) {
                    keywords.append(fallback)
                    break
                }
            }
        }

        if keywords.count > originalCount {
            logger.info("✨ [Vision] 폴백 키워드 추가됨 (원본 \(originalCount)개 → \(keywords.count)개)")
        }

        logger.info("✨ [Vision] 최종 키워드: \(keywords.joined(separator: ", "))")

        return Array(keywords.prefix(maxKeywords))
    }

    /// UIImage 배열에서 SNS용 감성 키워드 추출 (PHAsset 없이)
    func extractKeywords(from images: [UIImage], maxKeywords: Int = 5, context: TravelContext = .travel) async -> [String] {
        let isTravel = (context == .travel || context == .mixed)
        guard !images.isEmpty else {
            return isTravel ? ["여행", "추억", "힐링"] : ["일상", "추억", "힐링"]
        }

        logger.info("✨ [Vision] UIImage 키워드 추출 시작 - \(images.count)장, context: \(context.displayName)")

        // 최대 5장 샘플링
        let samples = Array(images.prefix(5))

        var categoryVotes: [SceneCategory: Float] = [:]

        for image in samples {
            let classifications = await classifyScene(image: image)

            for classification in classifications {
                categoryVotes[classification.category, default: 0] += classification.confidence
            }
        }

        // 카테고리별 점수 정렬
        let sortedCategories = categoryVotes
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }

        // Context에 맞는 키워드 매핑 선택
        let mapping = Self.keywordMapping(for: context)

        // 키워드 수집
        var keywordScores: [String: Float] = [:]

        for (index, category) in sortedCategories.enumerated() {
            let weight = Float(3 - index)
            if let categoryKeywords = mapping[category] {
                for keyword in categoryKeywords.prefix(2) {
                    keywordScores[keyword, default: 0] += weight
                }
            }
        }

        var keywords = keywordScores
            .sorted { $0.value > $1.value }
            .prefix(maxKeywords)
            .map { $0.key }

        // 최소 3개 보장
        let fallbackKeywords = isTravel
            ? ["여행", "추억", "힐링", "소중한시간", "행복"]
            : ["일상", "추억", "힐링", "소중한시간", "행복"]
        while keywords.count < 3 {
            for fallback in fallbackKeywords {
                if !keywords.contains(fallback) {
                    keywords.append(fallback)
                    break
                }
            }
        }

        logger.info("✨ [Vision] UIImage 키워드 추출 완료: \(keywords.joined(separator: ", "))")

        return Array(keywords.prefix(maxKeywords))
    }
}

// MARK: - iOS Version Check Extension

extension VisionAnalysisService {
    /// iOS 버전 확인
    static var isiOS18OrLater: Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }

    /// 사용 가능한 분석 레벨
    enum AnalysisLevel: String {
        case basic      // iOS 17: 기본 분석
        case advanced   // iOS 18+: 고급 분석

        var description: String {
            switch self {
            case .basic: return "기본 분석"
            case .advanced: return "고급 AI 분석"
            }
        }
    }

    static var availableAnalysisLevel: AnalysisLevel {
        isiOS18OrLater ? .advanced : .basic
    }
}
