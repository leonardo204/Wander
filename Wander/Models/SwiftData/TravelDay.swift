import Foundation
import SwiftData

@Model
final class TravelDay {
    var id: UUID
    var date: Date
    var dayNumber: Int
    var summary: String?

    var record: TravelRecord?

    @Relationship(deleteRule: .cascade, inverse: \Place.day)
    var places: [Place]

    init(date: Date, dayNumber: Int) {
        self.id = UUID()
        self.date = date
        self.dayNumber = dayNumber
        self.places = []
    }
}
