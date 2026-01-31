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
}
