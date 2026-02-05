import SwiftUI
import UIKit
import Photos

// MARK: - 공유 가능한 데이터 프로토콜

/// 공유 기능에서 사용할 수 있는 데이터 프로토콜
protocol ShareableData {
    var shareTitle: String { get }
    var shareDateRange: String { get }
    var sharePlaceCount: Int { get }
    var shareTotalDistance: Double { get }
    var sharePhotoAssetIdentifiers: [String] { get }
    var shareAIStory: String? { get }

    // 통합 통계 문자열 (날짜 포함)
    var shareStatsWithDate: String { get }

    // 감성 키워드 생성용 데이터
    var shareActivities: [String] { get }
    var shareAddresses: [String] { get }
    var shareStartDate: Date { get }
}

// MARK: - 공유 대상

/// 공유 대상 타입
enum ShareDestination: String, CaseIterable, Identifiable {
    case general = "general"           // 일반 공유 (UIActivityViewController)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general:
            return "일반 공유"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "square.and.arrow.up"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .general:
            return 4.0 / 5.0  // 4:5 비율
        }
    }

    var imageSize: CGSize {
        switch self {
        case .general:
            return CGSize(width: 1080, height: 1350)  // 4:5 비율
        }
    }
}

// MARK: - 템플릿 스타일

/// 공유 이미지 템플릿 스타일
enum ShareTemplateStyle: String, CaseIterable, Identifiable, Hashable {
    case modernGlass = "modern_glass"      // Style 1: 글래스 오버레이
    case polaroidGrid = "polaroid_grid"    // Style 2: 폴라로이드 그리드
    case cleanMinimal = "clean_minimal"    // Style 3: 미니멀

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modernGlass:
            return "Modern Glass"
        case .polaroidGrid:
            return "Polaroid"
        case .cleanMinimal:
            return "Minimal"
        }
    }

    var description: String {
        switch self {
        case .modernGlass:
            return "사진 전체 배경 + 글래스 패널"
        case .polaroidGrid:
            return "폴라로이드 스타일 그리드"
        case .cleanMinimal:
            return "깔끔한 미니멀 디자인"
        }
    }
}

// MARK: - 공유 설정

/// 공유 이미지 생성 설정
struct ShareConfiguration {
    var destination: ShareDestination
    var templateStyle: ShareTemplateStyle
    var selectedPhotoIndices: [Int]  // 선택된 사진 인덱스
    var caption: String              // 클립보드용 캡션 (SNS 게시글)
    var impression: String           // 이미지 내 감성 키워드 (로맨틱 · 힐링 · 도심탈출)
    var hashtags: [String]
    var showWatermark: Bool

    init(
        destination: ShareDestination = .general,
        templateStyle: ShareTemplateStyle = .modernGlass,
        selectedPhotoIndices: [Int] = [],
        caption: String = "",
        impression: String = "",
        hashtags: [String] = [],
        showWatermark: Bool = true
    ) {
        self.destination = destination
        self.templateStyle = templateStyle
        self.selectedPhotoIndices = selectedPhotoIndices
        self.caption = caption
        self.impression = impression
        self.hashtags = hashtags
        self.showWatermark = showWatermark
    }

    /// 해시태그 문자열 (공유용)
    var hashtagString: String {
        hashtags.map { "#\($0)" }.joined(separator: " ")
    }

    /// 클립보드에 복사할 전체 텍스트 (캡션 + 해시태그)
    var clipboardText: String {
        var text = caption
        if !hashtags.isEmpty {
            if !text.isEmpty {
                text += "\n\n"
            }
            text += hashtagString
        }
        return text
    }
}

// MARK: - 공유용 사진 아이템

/// 공유 화면에서 사용할 사진 아이템
struct SharePhotoItem: Identifiable, Equatable {
    let id: String  // PHAsset localIdentifier
    var image: UIImage?
    var isSelected: Bool
    var order: Int

    init(assetIdentifier: String, image: UIImage? = nil, isSelected: Bool = true, order: Int = 0) {
        self.id = assetIdentifier
        self.image = image
        self.isSelected = isSelected
        self.order = order
    }
}

// MARK: - 감성 키워드 생성 (Impression)

/// 여행 데이터 기반 감성 키워드 생성
/// SNS 공유에 적합한 강한 명사/형용사 조합
struct ImpressionGenerator {

    // MARK: - 키워드 풀

    /// 분위기 키워드
    private static let moodKeywords = [
        "로맨틱", "힐링", "여유", "설렘", "평화로운", "특별한"
    ]

    /// 활동 키워드
    private static let activityKeywords: [String: [String]] = [
        "카페": ["감성카페", "카페투어", "브런치", "여유"],
        "맛집": ["맛집투어", "미식", "먹방", "로컬푸드"],
        "관광": ["시티투어", "관광", "여행", "투어"],
        "쇼핑": ["쇼핑", "힙스터", "빈티지"],
        "해변": ["바다", "파도", "서핑", "일몰"],
        "자연": ["힐링", "트레킹", "자연", "숲속"],
        "문화": ["문화탐방", "전시", "역사"],
        "휴식": ["충전", "리프레시", "힐링"]
    ]

    /// 지역 키워드
    private static let regionKeywords: [String: [String]] = [
        "제주": ["제주감성", "돌담길", "오름", "바다"],
        "부산": ["해운대", "광안리", "바다", "야경"],
        "강원": ["자연", "힐링", "청량함", "산"],
        "서울": ["도심", "야경", "시티라이프"],
        "경주": ["역사", "고즈넉함", "힐링"]
    ]

    /// 계절 키워드
    private static let seasonKeywords: [Int: [String]] = [
        3: ["봄꽃", "벚꽃", "설렘"],      // 봄
        4: ["봄꽃", "벚꽃", "피크닉"],
        5: ["초여름", "싱그러움", "여유"],
        6: ["초여름", "바다", "여름시작"],  // 여름
        7: ["한여름", "바다", "피서"],
        8: ["바다", "휴가", "여름끝"],
        9: ["가을", "단풍", "청량함"],     // 가을
        10: ["단풍", "가을감성", "낭만"],
        11: ["늦가을", "쓸쓸함", "감성"],
        12: ["겨울", "설경", "따뜻함"],    // 겨울
        1: ["겨울여행", "눈", "힐링"],
        2: ["겨울끝", "봄기운", "설렘"]
    ]

    // MARK: - Public Methods

    /// 감성 키워드 생성 (최대 3개)
    static func generate(
        activities: [String],
        addresses: [String],
        date: Date
    ) -> [String] {
        var keywords: [String] = []

        // 1. 지역 기반 키워드 (1개)
        if let regionKeyword = selectRegionKeyword(from: addresses) {
            keywords.append(regionKeyword)
        }

        // 2. 활동 기반 키워드 (1개)
        if let activityKeyword = selectActivityKeyword(from: activities) {
            keywords.append(activityKeyword)
        }

        // 3. 계절/분위기 기반 키워드 (1개)
        let moodKeyword = selectMoodKeyword(from: date)
        keywords.append(moodKeyword)

        // 중복 제거 및 최대 3개 제한
        let uniqueKeywords = Array(Set(keywords))

        // 3개 미만이면 기본 키워드 추가
        var result = Array(uniqueKeywords.prefix(3))
        let defaults = ["추억", "소중한시간", "행복"]
        while result.count < 3 {
            for keyword in defaults {
                if !result.contains(keyword) {
                    result.append(keyword)
                    break
                }
            }
            // 무한루프 방지
            if result.count < 3 && result.count == Array(Set(result + defaults)).count {
                result.append("여행")
            }
        }

        return Array(result.prefix(3))
    }

    /// 기본 감성 키워드 (데이터 없을 때 사용)
    static let defaultImpression = "소중한 추억"

    /// 키워드 문자열 생성 (구분자로 연결)
    static func generateString(
        activities: [String],
        addresses: [String],
        date: Date,
        separator: String = " · "
    ) -> String {
        let keywords = generate(activities: activities, addresses: addresses, date: date)
        return keywords.joined(separator: separator)
    }

    // MARK: - Private Methods

    private static func selectRegionKeyword(from addresses: [String]) -> String? {
        for (region, keywords) in regionKeywords {
            for address in addresses {
                if address.contains(region) {
                    return keywords.randomElement()
                }
            }
        }
        return nil
    }

    private static func selectActivityKeyword(from activities: [String]) -> String? {
        // 활동 빈도 계산
        var activityCounts: [String: Int] = [:]
        for activity in activities {
            for (key, _) in activityKeywords {
                if activity.contains(key) {
                    activityCounts[key, default: 0] += 1
                }
            }
        }

        // 가장 많은 활동 유형 선택
        if let topActivity = activityCounts.max(by: { $0.value < $1.value })?.key,
           let keywords = activityKeywords[topActivity] {
            return keywords.randomElement()
        }

        return nil
    }

    private static func selectMoodKeyword(from date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)

        if let seasonKeyword = seasonKeywords[month]?.randomElement() {
            return seasonKeyword
        }

        return moodKeywords.randomElement() ?? "힐링"
    }
}

// MARK: - 추천 해시태그

/// 여행 데이터 기반 추천 해시태그 생성
struct HashtagRecommendation {

    /// 지역 기반 해시태그 생성
    static func locationHashtags(from addresses: [String]) -> [String] {
        var hashtags: [String] = []

        for address in addresses {
            // 시/도 추출
            if address.contains("제주") {
                hashtags.append("제주도여행")
                hashtags.append("제주맛집")
            } else if address.contains("부산") {
                hashtags.append("부산여행")
                hashtags.append("부산맛집")
            } else if address.contains("서울") {
                hashtags.append("서울여행")
                hashtags.append("서울맛집")
            } else if address.contains("강원") || address.contains("속초") || address.contains("강릉") {
                hashtags.append("강원도여행")
            } else if address.contains("경주") {
                hashtags.append("경주여행")
            }
        }

        return Array(Set(hashtags))  // 중복 제거
    }

    /// 시즌 기반 해시태그 생성
    static func seasonHashtags(from date: Date) -> [String] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)

        var hashtags: [String] = []

        // 월 해시태그
        hashtags.append("\(month)월여행")

        // 계절 해시태그
        switch month {
        case 3...5:
            hashtags.append("봄여행")
            hashtags.append("벚꽃여행")
        case 6...8:
            hashtags.append("여름여행")
            hashtags.append("바다여행")
        case 9...11:
            hashtags.append("가을여행")
            hashtags.append("단풍여행")
        case 12, 1, 2:
            hashtags.append("겨울여행")
        default:
            break
        }

        return hashtags
    }

    /// 일반 여행 해시태그
    static var generalHashtags: [String] {
        [
            "여행스타그램",
            "여행기록",
            "국내여행",
            "여행에미치다",
            "여행사진",
            "일상기록"
        ]
    }

    /// 활동 기반 해시태그
    static func activityHashtags(from activities: [String]) -> [String] {
        var hashtags: [String] = []

        for activity in activities {
            if activity.contains("카페") {
                hashtags.append("카페투어")
                hashtags.append("카페스타그램")
            }
            if activity.contains("맛집") || activity.contains("식사") || activity.contains("레스토랑") {
                hashtags.append("맛집탐방")
                hashtags.append("먹스타그램")
            }
            if activity.contains("해변") || activity.contains("바다") {
                hashtags.append("바다스타그램")
            }
            if activity.contains("산") || activity.contains("등산") {
                hashtags.append("등산스타그램")
            }
        }

        return Array(Set(hashtags))
    }
}

// MARK: - 공유 에러

/// 공유 관련 에러
enum ShareError: LocalizedError {
    case noPhotosSelected
    case imageGenerationFailed
    case clipboardFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .noPhotosSelected:
            return "공유할 사진을 선택해주세요."
        case .imageGenerationFailed:
            return "이미지 생성에 실패했습니다."
        case .clipboardFailed:
            return "클립보드 복사에 실패했습니다."
        case .unknown(let error):
            return "오류가 발생했습니다: \(error.localizedDescription)"
        }
    }
}

// MARK: - 공유 결과

/// 공유 작업 결과
enum ShareResult {
    case success
    case cancelled
    case failed(ShareError)
}
