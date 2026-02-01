import Foundation
import SwiftData

@Model
final class TravelRecord {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var recordType: String
    var totalDistance: Double
    var placeCount: Int
    var photoCount: Int
    var aiStory: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TravelDay.record)
    var days: [TravelDay]

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        recordType: String = "travel"
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.recordType = recordType
        self.totalDistance = 0
        self.placeCount = 0
        self.photoCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.days = []
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
