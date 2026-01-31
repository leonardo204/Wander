import SwiftUI
import MapKit

struct MapDetailView: View {
    let places: [PlaceCluster]
    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedPlace: PlaceCluster?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map
            Map(position: $camera, selection: $selectedPlace) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        PlaceAnnotationView(
                            number: index + 1,
                            activityType: place.activityType,
                            isSelected: selectedPlace?.id == place.id
                        )
                    }
                    .tag(place)
                }

                // Route polyline
                if places.count > 1 {
                    MapPolyline(coordinates: places.map { $0.coordinate })
                        .stroke(WanderColors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            // Selected Place Card
            if let place = selectedPlace {
                PlaceDetailCard(place: place)
                    .padding(WanderSpacing.screenMargin)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("지도")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { fitAllPlaces() }) {
                        Label("전체 보기", systemImage: "arrow.up.left.and.arrow.down.right")
                    }

                    Button(action: { resetToFirstPlace() }) {
                        Label("시작점으로", systemImage: "arrow.uturn.backward")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            fitAllPlaces()
        }
    }

    private func fitAllPlaces() {
        guard !places.isEmpty else { return }

        let coordinates = places.map { $0.coordinate }
        let region = MKCoordinateRegion(coordinates: coordinates)

        camera = .region(region)
    }

    private func resetToFirstPlace() {
        guard let first = places.first else { return }

        camera = .region(MKCoordinateRegion(
            center: first.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
}

// MARK: - Place Annotation View
struct PlaceAnnotationView: View {
    let number: Int
    let activityType: ActivityType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Pin body
                Circle()
                    .fill(.white)
                    .frame(width: isSelected ? 48 : 36, height: isSelected ? 48 : 36)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Circle()
                    .fill(isSelected ? WanderColors.primary : activityType.color)
                    .frame(width: isSelected ? 42 : 30, height: isSelected ? 42 : 30)

                if isSelected {
                    Text(activityType.emoji)
                        .font(.system(size: 20))
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(WanderColors.textPrimary)
                }
            }

            // Pin tail
            Triangle()
                .fill(.white)
                .frame(width: 12, height: 8)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Place Detail Card
struct PlaceDetailCard: View {
    let place: PlaceCluster

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                // Activity icon
                ZStack {
                    Circle()
                        .fill(place.activityType.color)
                        .frame(width: 44, height: 44)

                    Text(place.activityType.emoji)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(place.address)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: WanderSpacing.space5) {
                // Time
                HStack(spacing: WanderSpacing.space1) {
                    Image(systemName: "clock")
                        .foregroundColor(WanderColors.textTertiary)
                    Text(formatTime(place.startTime))
                        .foregroundColor(WanderColors.textSecondary)
                }
                .font(WanderTypography.caption1)

                // Photos
                HStack(spacing: WanderSpacing.space1) {
                    Image(systemName: "photo")
                        .foregroundColor(WanderColors.textTertiary)
                    Text("\(place.photos.count)장")
                        .foregroundColor(WanderColors.textSecondary)
                }
                .font(WanderTypography.caption1)

                // Activity
                HStack(spacing: WanderSpacing.space1) {
                    Text(place.activityType.emoji)
                    Text(place.activityType.displayName)
                        .foregroundColor(WanderColors.textSecondary)
                }
                .font(WanderTypography.caption1)
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surfaceElevated)
        .cornerRadius(WanderSpacing.radiusXL)
        .elevation2()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - MKCoordinateRegion Extension
extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.01,
            longitudeDelta: (maxLon - minLon) * 1.5 + 0.01
        )

        self.init(center: center, span: span)
    }
}

#Preview {
    NavigationStack {
        MapDetailView(places: [])
    }
}
