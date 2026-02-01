import Foundation
import SwiftData

@Model
final class PhotoItem {
    var id: UUID
    var assetIdentifier: String
    var capturedAt: Date?
    var latitude: Double?
    var longitude: Double?
    var hasGPS: Bool
    var order: Int

    var place: Place?

    init(
        assetIdentifier: String,
        capturedAt: Date?,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.hasGPS = latitude != nil && longitude != nil
        self.order = 0
    }
}
