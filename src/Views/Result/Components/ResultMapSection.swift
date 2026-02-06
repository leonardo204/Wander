import SwiftUI
import MapKit

struct ResultMapSection: View {
    let places: [PlaceCluster]

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 동선")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                // 유효한 좌표가 있는 장소만 지도에 표시 (미분류 사진 제외)
                let validPlaces = places.filter { $0.hasValidCoordinate }
                NavigationLink(destination: MapDetailView(places: validPlaces)) {
                    HStack(spacing: WanderSpacing.space1) {
                        Text("전체 보기")
                            .font(WanderTypography.caption1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(WanderColors.primary)
                }
            }

            // Mini Map - 유효한 좌표가 있는 장소만 표시
            let validPlacesForMap = places.filter { $0.hasValidCoordinate }
            Map {
                ForEach(Array(validPlacesForMap.enumerated()), id: \.element.id) { index, place in
                    Annotation("", coordinate: place.coordinate) {
                        PlaceMarker(number: index + 1, activityType: place.activityType)
                    }
                }

                if validPlacesForMap.count > 1 {
                    MapPolyline(coordinates: validPlacesForMap.map { $0.coordinate })
                        .stroke(WanderColors.primary, lineWidth: 3)
                }
            }
            .frame(height: 200)
            .cornerRadius(WanderSpacing.radiusLarge)
            .disabled(true) // Make it non-interactive for preview
        }
    }
}

// MARK: - Place Marker
struct PlaceMarker: View {
    let number: Int
    let activityType: ActivityType

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.2), radius: 4)

            Circle()
                .fill(WanderColors.primary)
                .frame(width: 28, height: 28)

            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
