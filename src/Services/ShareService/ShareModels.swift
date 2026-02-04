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
}

// MARK: - 공유 대상

/// 공유 대상 타입
enum ShareDestination: String, CaseIterable, Identifiable {
    case general = "general"           // 일반 공유 (UIActivityViewController)
    case instagramFeed = "instagram_feed"   // Instagram Feed (4:5)
    case instagramStory = "instagram_story" // Instagram Story (9:16)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general:
            return "일반 공유"
        case .instagramFeed:
            return "Instagram 피드"
        case .instagramStory:
            return "Instagram 스토리"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "square.and.arrow.up"
        case .instagramFeed:
            return "camera"
        case .instagramStory:
            return "camera.circle"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .general, .instagramFeed:
            return 4.0 / 5.0  // 1080 x 1350
        case .instagramStory:
            return 9.0 / 16.0  // 1080 x 1920
        }
    }

    var imageSize: CGSize {
        switch self {
        case .general:
            return CGSize(width: 810, height: 1012)  // 일반 공유용 (75% 축소)
        case .instagramFeed:
            return CGSize(width: 1080, height: 1350) // Instagram Feed 원본 유지
        case .instagramStory:
            return CGSize(width: 1080, height: 1920) // Instagram Story 원본 유지
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
    var caption: String
    var hashtags: [String]
    var showWatermark: Bool

    init(
        destination: ShareDestination = .general,
        templateStyle: ShareTemplateStyle = .modernGlass,
        selectedPhotoIndices: [Int] = [],
        caption: String = "",
        hashtags: [String] = [],
        showWatermark: Bool = true
    ) {
        self.destination = destination
        self.templateStyle = templateStyle
        self.selectedPhotoIndices = selectedPhotoIndices
        self.caption = caption
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
    case instagramNotInstalled
    case clipboardFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .noPhotosSelected:
            return "공유할 사진을 선택해주세요."
        case .imageGenerationFailed:
            return "이미지 생성에 실패했습니다."
        case .instagramNotInstalled:
            return "Instagram이 설치되어 있지 않습니다."
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
