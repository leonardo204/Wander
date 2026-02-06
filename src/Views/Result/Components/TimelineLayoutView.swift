import SwiftUI
import Photos

struct TimelineLayoutView: View {
    let places: [PlaceCluster]

    var body: some View {
        let groupedByDate = groupPlacesByDate()
        let sortedDates = groupedByDate.keys.sorted()

        return VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("타임라인")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            ForEach(Array(sortedDates.enumerated()), id: \.element) { dayIndex, date in
                // Day header
                DayHeader(dayNumber: dayIndex + 1, date: date)

                // Places for this day
                if let placesForDay = groupedByDate[date] {
                    let sortedPlaces = placesForDay.sorted { $0.startTime < $1.startTime }
                    ForEach(Array(sortedPlaces.enumerated()), id: \.element.id) { placeIndex, place in
                        TimelineCard(
                            place: place,
                            index: placeIndex,
                            isLast: placeIndex == sortedPlaces.count - 1
                        )
                    }
                }
            }
        }
    }

    /// 장소를 날짜별로 그룹화
    private func groupPlacesByDate() -> [Date: [PlaceCluster]] {
        let calendar = Calendar.current
        var grouped: [Date: [PlaceCluster]] = [:]

        for place in places {
            let dateOnly = calendar.startOfDay(for: place.startTime)
            if grouped[dateOnly] == nil {
                grouped[dateOnly] = []
            }
            grouped[dateOnly]?.append(place)
        }

        return grouped
    }
}

// MARK: - Day Header
struct DayHeader: View {
    let dayNumber: Int
    let date: Date

    var body: some View {
        HStack(spacing: WanderSpacing.space3) {
            Text(formatDate(date))
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.primary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space1)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusMedium)

            Spacer()
        }
        .padding(.top, dayNumber > 1 ? WanderSpacing.space4 : 0)
        .padding(.bottom, WanderSpacing.space2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

// MARK: - Timeline Card
struct TimelineCard: View {
    let place: PlaceCluster
    let index: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: WanderSpacing.space4) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Number circle - Vision 분석 결과 우선 사용
                ZStack {
                    Circle()
                        .fill(placeColor)
                        .frame(width: 36, height: 36)

                    Text(place.displayEmoji)
                        .font(.system(size: 16))
                }

                // Connector line
                if !isLast {
                    Rectangle()
                        .fill(WanderColors.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                // Time
                Text(formatTime(place.startTime))
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)

                // Place name (betterName 우선 사용)
                Text(place.displayName)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                // Address
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(1)
                }

                // Activity/Scene tag
                HStack(spacing: WanderSpacing.space1) {
                    Text(place.displayEmoji)
                    Text(activityLabel)
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
                .padding(.horizontal, WanderSpacing.space2)
                .padding(.vertical, WanderSpacing.space1)
                .background(placeColor)
                .cornerRadius(WanderSpacing.radiusSmall)

                // 주변 핫스팟 (스마트 분석 결과)
                if let hotspots = place.nearbyHotspots, !hotspots.isEmpty {
                    nearbyHotspotsView(hotspots)
                }

                // Photo count
                Text("사진 \(place.photos.count)장")
                    .font(WanderTypography.caption2)
                    .foregroundColor(WanderColors.textTertiary)
            }
            .padding(.bottom, isLast ? 0 : WanderSpacing.space4)

            Spacer()
        }
    }

    // 장면 분류 기반 색상 (있으면 사용, 없으면 기본 활동 색상)
    private var placeColor: Color {
        if let scene = place.sceneCategory {
            return scene.toActivityType.color
        }
        return place.activityType.color
    }

    // 활동 라벨 (장면 분류 우선)
    private var activityLabel: String {
        if let scene = place.sceneCategory, scene != .unknown {
            return scene.koreanName
        }
        return place.activityType.displayName
    }

    // 주변 핫스팟 뷰
    @ViewBuilder
    private func nearbyHotspotsView(_ hotspots: POIService.NearbyHotspots) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space1) {
            Text("주변")
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WanderSpacing.space2) {
                    // 카페
                    ForEach(hotspots.cafes.prefix(2)) { poi in
                        HotspotChip(emoji: "☕", name: poi.name)
                    }

                    // 맛집
                    ForEach(hotspots.restaurants.prefix(2)) { poi in
                        HotspotChip(emoji: "🍽️", name: poi.name)
                    }

                    // 명소
                    ForEach(hotspots.attractions.prefix(2)) { poi in
                        HotspotChip(emoji: "📸", name: poi.name)
                    }
                }
            }
        }
        .padding(.top, WanderSpacing.space1)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Hotspot Chip
struct HotspotChip: View {
    let emoji: String
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 10))
            Text(name)
                .font(WanderTypography.caption2)
                .lineLimit(1)
        }
        .foregroundColor(WanderColors.textSecondary)
        .padding(.horizontal, WanderSpacing.space2)
        .padding(.vertical, 4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusSmall)
    }
}
