import Foundation
import SwiftData
import CoreLocation

@Model
final class Place {
    var id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var placeType: String
    var activityLabel: String
    var startTime: Date
    var endTime: Date?
    var memo: String?
    var order: Int

    var day: TravelDay?

    @Relationship(deleteRule: .cascade, inverse: \PhotoItem.place)
    var photos: [PhotoItem]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        startTime: Date
    ) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.placeType = "other"
        self.activityLabel = "기타"
        self.startTime = startTime
        self.order = 0
        self.photos = []
    }
}
