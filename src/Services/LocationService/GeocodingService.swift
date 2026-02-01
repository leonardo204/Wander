import Foundation
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "GeocodingService")

class GeocodingService {
    private let geocoder = CLGeocoder()

    struct GeocodingResult {
        var name: String
        var fullAddress: String
        var placeType: String?
        var locality: String?
        var subLocality: String?
        var thoroughfare: String?
    }

    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeocodingResult {
        logger.info("🗺️ [Geocoding] reverseGeocode 호출: (\(latitude), \(longitude))")
        let location = CLLocation(latitude: latitude, longitude: longitude)

        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        logger.info("🗺️ [Geocoding] placemarks 개수: \(placemarks.count)")

        guard let placemark = placemarks.first else {
            logger.warning("🗺️ [Geocoding] placemark 없음")
            throw GeocodingError.noResults
        }
        logger.info("🗺️ [Geocoding] placemark.name: \(placemark.name ?? "nil")")

        // Build name
        var name = ""
        if let poi = placemark.name, !poi.isEmpty {
            name = poi
        } else if let subLocality = placemark.subLocality {
            name = subLocality
        } else if let locality = placemark.locality {
            name = locality
        } else {
            name = "알 수 없는 장소"
        }

        // Build full address
        var addressComponents: [String] = []

        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        if let subLocality = placemark.subLocality {
            addressComponents.append(subLocality)
        }
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }

        let fullAddress = addressComponents.joined(separator: " ")

        // Determine place type
        let placeType = determinePlaceType(from: placemark)

        return GeocodingResult(
            name: name,
            fullAddress: fullAddress,
            placeType: placeType,
            locality: placemark.locality,
            subLocality: placemark.subLocality,
            thoroughfare: placemark.thoroughfare
        )
    }

    private func determinePlaceType(from placemark: CLPlacemark) -> String? {
        // Check POI categories from placemark
        if let areasOfInterest = placemark.areasOfInterest, !areasOfInterest.isEmpty {
            let poi = areasOfInterest[0].lowercased()

            if poi.contains("cafe") || poi.contains("coffee") || poi.contains("카페") {
                return "cafe"
            }
            if poi.contains("restaurant") || poi.contains("식당") || poi.contains("음식점") {
                return "restaurant"
            }
            if poi.contains("beach") || poi.contains("해변") || poi.contains("해수욕장") {
                return "beach"
            }
            if poi.contains("mountain") || poi.contains("산") || poi.contains("등산") {
                return "mountain"
            }
            if poi.contains("airport") || poi.contains("공항") {
                return "airport"
            }
            if poi.contains("museum") || poi.contains("gallery") || poi.contains("박물관") || poi.contains("미술관") {
                return "culture"
            }
            if poi.contains("mall") || poi.contains("store") || poi.contains("shop") || poi.contains("백화점") {
                return "shopping"
            }
            if poi.contains("park") || poi.contains("공원") || poi.contains("temple") || poi.contains("사찰") {
                return "tourist"
            }
        }

        // Fallback: check name
        if let name = placemark.name?.lowercased() {
            if name.contains("카페") || name.contains("coffee") || name.contains("스타벅스") {
                return "cafe"
            }
            if name.contains("식당") || name.contains("맛집") || name.contains("레스토랑") {
                return "restaurant"
            }
            if name.contains("해변") || name.contains("해수욕장") || name.contains("beach") {
                return "beach"
            }
        }

        return nil
    }
}

enum GeocodingError: LocalizedError {
    case noResults
    case networkError

    var errorDescription: String? {
        switch self {
        case .noResults:
            return "주소를 찾을 수 없습니다"
        case .networkError:
            return "네트워크 오류가 발생했습니다"
        }
    }
}
