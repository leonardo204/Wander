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
}
