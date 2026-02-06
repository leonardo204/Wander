import Foundation
import SwiftData

@Model
final class TravelRecord {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var totalDistance: Double
    var placeCount: Int
    var photoCount: Int
    var aiStory: String?
    var createdAt: Date
    var updatedAt: Date
    var isHidden: Bool = false
    
    /// 결과 화면 레이아웃 타입 (timeline, magazine, grid)
    var layoutType: String = "timeline"
    
    /// 여행 테마 (예: "식도락", "힐링", "액티비티" 등)
    var theme: String?

    // MARK: - P2P Share Fields (공유 관련)

    /// 공유받은 기록 여부
    var isShared: Bool = false

    /// 공유자 이름 (선택적)
    var sharedFrom: String?

    /// 공유받은 시간
    var sharedAt: Date?

    /// 원본 공유 ID (중복 저장 방지용)
    var originalShareID: UUID?

    /// 공유 기록 만료일 (nil이면 영구 보관)
    var shareExpiresAt: Date?

    // MARK: - AI Enhancement State

    /// AI 다듬기 적용 여부
    var isAIEnhanced: Bool = false

    /// AI 다듬기 적용 시간
    var aiEnhancedAt: Date?

    /// AI 다듬기에 사용된 프로바이더명
    var aiEnhancedProvider: String?

    /// AI가 다듬은 TravelDNA 설명
    var aiEnhancedDNADescription: String?

    // MARK: - Wander Intelligence Data (JSON 직렬화)

    /// 여행 점수 데이터 (JSON)
    var tripScoreJSON: String?

    /// 여행자 DNA 데이터 (JSON)
    var travelDNAJSON: String?

    /// 인사이트 데이터 (JSON)
    var insightsJSON: String?

    /// 여행 스토리 데이터 (JSON)
    var travelStoryJSON: String?

    /// 획득한 배지 목록 (JSON)
    var badgesJSON: String?

    /// 분석 레벨 (basic, smart, advanced)
    var analysisLevel: String?

    /// Vision 분석으로 추출된 감성 키워드 (JSON)
    var keywordsJSON: String?

    @Relationship(deleteRule: .cascade, inverse: \TravelDay.record)
    var days: [TravelDay]

    /// 기록 카테고리 (여행, 일상, 주간, 출장 등)
    @Relationship(deleteRule: .nullify, inverse: \RecordCategory.records)
    var category: RecordCategory?

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        category: RecordCategory? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.totalDistance = 0
        self.placeCount = 0
        self.photoCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isHidden = false
        self.days = []
    }

    /// 카테고리 이름 (없으면 "여행" 기본값)
    var categoryName: String {
        category?.name ?? "여행"
    }

    /// 카테고리 아이콘 (없으면 ✈️ 기본값)
    var categoryIcon: String {
        category?.icon ?? "✈️"
    }

    // MARK: - Share Expiration Computed Properties

    /// 공유 기록이 만료되었는지 확인
    var isShareExpired: Bool {
        guard isShared, let expiresAt = shareExpiresAt else { return false }
        return expiresAt < Date()
    }

    /// 만료까지 남은 일수 (nil이면 영구 또는 비공유)
    var daysUntilExpiration: Int? {
        guard isShared, let expiresAt = shareExpiresAt else { return nil }
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: expiresAt)
        let components = calendar.dateComponents([.day], from: now, to: expiry)
        return components.day
    }

    /// 만료 상태 (배지 표시용)
    var expirationStatus: ShareExpirationStatus {
        guard isShared else { return .notShared }
        guard let days = daysUntilExpiration else { return .permanent }

        if days < 0 {
            return .expired
        } else if days == 0 {
            return .today
        } else if days <= 3 {
            return .soon(days: days)
        } else {
            return .normal(days: days)
        }
    }
}

/// 공유 기록 만료 상태
enum ShareExpirationStatus {
    case notShared          // 공유 기록 아님
    case permanent          // 영구 보관
    case normal(days: Int)  // 여유 있음 (D-N)
    case soon(days: Int)    // 곧 만료 (D-3 이하)
    case today              // 오늘 만료
    case expired            // 만료됨
}

extension TravelRecord {

    /// 첫 번째 사진의 assetIdentifier 반환 (썸네일용)
    var firstPhotoAssetIdentifier: String? {
        // days를 날짜순으로 정렬하고, 각 day의 places를 순서대로 확인
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }
        for day in sortedDays {
            let sortedPlaces = day.places.sorted { $0.order < $1.order }
            for place in sortedPlaces {
                if let firstPhoto = place.photos.sorted(by: { $0.order < $1.order }).first {
                    return firstPhoto.assetIdentifier
                }
            }
        }
        return nil
    }

    /// 첫 번째 사진 (공유받은 사진 포함)
    var firstPhoto: PhotoItem? {
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }
        for day in sortedDays {
            let sortedPlaces = day.places.sorted { $0.order < $1.order }
            for place in sortedPlaces {
                if let firstPhoto = place.photos.sorted(by: { $0.order < $1.order }).first {
                    return firstPhoto
                }
            }
        }
        return nil
    }

    /// 첫 번째 사진의 localFilePath 반환 (공유받은 사진의 썸네일용)
    var firstPhotoLocalPath: String? {
        firstPhoto?.localFilePath
    }

    /// 모든 사진의 assetIdentifier 목록 반환 (공유받은 사진 제외)
    var allPhotoAssetIdentifiers: [String] {
        var identifiers: [String] = []
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }
        for day in sortedDays {
            let sortedPlaces = day.places.sorted { $0.order < $1.order }
            for place in sortedPlaces {
                let sortedPhotos = place.photos.sorted { $0.order < $1.order }
                identifiers.append(contentsOf: sortedPhotos.compactMap { $0.assetIdentifier })
            }
        }
        return identifiers
    }

    /// 모든 사진 목록 반환 (공유받은 사진 포함)
    var allPhotos: [PhotoItem] {
        var photos: [PhotoItem] = []
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }
        for day in sortedDays {
            let sortedPlaces = day.places.sorted { $0.order < $1.order }
            for place in sortedPlaces {
                let sortedPhotos = place.photos.sorted { $0.order < $1.order }
                photos.append(contentsOf: sortedPhotos)
            }
        }
        return photos
    }

    // MARK: - Wander Intelligence Computed Properties

    /// 여행 점수 (역직렬화)
    var tripScore: MomentScoreService.TripOverallScore? {
        get {
            guard let json = tripScoreJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(MomentScoreService.TripOverallScore.self, from: data)
        }
        set {
            if let value = newValue,
               let data = try? JSONEncoder().encode(value) {
                tripScoreJSON = String(data: data, encoding: .utf8)
            } else {
                tripScoreJSON = nil
            }
        }
    }

    /// 여행자 DNA (역직렬화)
    var travelDNA: TravelDNAService.TravelDNA? {
        get {
            guard let json = travelDNAJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(TravelDNAService.TravelDNA.self, from: data)
        }
        set {
            if let value = newValue,
               let data = try? JSONEncoder().encode(value) {
                travelDNAJSON = String(data: data, encoding: .utf8)
            } else {
                travelDNAJSON = nil
            }
        }
    }

    /// 인사이트 목록 (역직렬화)
    var insights: [InsightEngine.TravelInsight] {
        get {
            guard let json = insightsJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([InsightEngine.TravelInsight].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                insightsJSON = String(data: data, encoding: .utf8)
            } else {
                insightsJSON = nil
            }
        }
    }

    /// 여행 스토리 (역직렬화)
    var travelStory: StoryWeavingService.TravelStory? {
        get {
            guard let json = travelStoryJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(StoryWeavingService.TravelStory.self, from: data)
        }
        set {
            if let value = newValue,
               let data = try? JSONEncoder().encode(value) {
                travelStoryJSON = String(data: data, encoding: .utf8)
            } else {
                travelStoryJSON = nil
            }
        }
    }

    /// 획득한 배지 목록 (역직렬화)
    var badges: [MomentScoreService.SpecialBadge] {
        get {
            guard let json = badgesJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([MomentScoreService.SpecialBadge].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                badgesJSON = String(data: data, encoding: .utf8)
            } else {
                badgesJSON = nil
            }
        }
    }

    /// Wander Intelligence 데이터 유무
    var hasWanderIntelligence: Bool {
        tripScoreJSON != nil || travelDNAJSON != nil || travelStoryJSON != nil
    }

    // MARK: - Vision Keywords (SNS 공유용 감성 키워드)

    /// 감성 키워드 배열 (역직렬화)
    var keywords: [String] {
        get {
            guard let json = keywordsJSON,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                keywordsJSON = String(data: data, encoding: .utf8)
            } else {
                keywordsJSON = nil
            }
        }
    }

    /// 키워드가 있는지 여부
    var hasKeywords: Bool {
        !keywords.isEmpty
    }

    /// 키워드 문자열 (구분자 연결, 기본값 " · ")
    func keywordsString(separator: String = " · ") -> String {
        keywords.isEmpty ? "" : keywords.joined(separator: separator)
    }
}
