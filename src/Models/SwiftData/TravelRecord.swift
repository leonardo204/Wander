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

    /// 모든 사진의 assetIdentifier 목록 반환
    var allPhotoAssetIdentifiers: [String] {
        var identifiers: [String] = []
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }
        for day in sortedDays {
            let sortedPlaces = day.places.sorted { $0.order < $1.order }
            for place in sortedPlaces {
                let sortedPhotos = place.photos.sorted { $0.order < $1.order }
                identifiers.append(contentsOf: sortedPhotos.map { $0.assetIdentifier })
            }
        }
        return identifiers
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
