import SwiftUI
import MapKit
import Photos

struct ResultView: View {
    let result: AnalysisResult
    let selectedAssets: [PHAsset]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showShareSheet = false
    @State private var isSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    // Map Section
                    mapSection

                    // Stats Section
                    statsSection

                    // Timeline Section
                    timelineSection

                    // Action Buttons
                    actionButtons
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }
            .background(WanderColors.background)
            .navigationTitle(result.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheetView(result: result)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 동선")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                NavigationLink(destination: MapDetailView(places: result.places)) {
                    HStack(spacing: WanderSpacing.space1) {
                        Text("전체 보기")
                            .font(WanderTypography.caption1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(WanderColors.primary)
                }
            }

            // Mini Map
            Map {
                ForEach(Array(result.places.enumerated()), id: \.element.id) { index, place in
                    Annotation("", coordinate: place.coordinate) {
                        PlaceMarker(number: index + 1, activityType: place.activityType)
                    }
                }

                if result.places.count > 1 {
                    MapPolyline(coordinates: result.places.map { $0.coordinate })
                        .stroke(WanderColors.primary, lineWidth: 3)
                }
            }
            .frame(height: 200)
            .cornerRadius(WanderSpacing.radiusLarge)
            .disabled(true) // Make it non-interactive for preview
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: WanderSpacing.space4) {
            StatCard(
                icon: "mappin.circle.fill",
                value: "\(result.placeCount)",
                label: "방문 장소"
            )

            StatCard(
                icon: "car.fill",
                value: String(format: "%.1f", result.totalDistance),
                label: "이동 거리 (km)"
            )

            StatCard(
                icon: "photo.fill",
                value: "\(result.photoCount)",
                label: "사진"
            )
        }
    }

    // MARK: - Timeline Section
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("타임라인")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            ForEach(Array(result.places.enumerated()), id: \.element.id) { index, place in
                TimelineCard(
                    place: place,
                    index: index,
                    isLast: index == result.places.count - 1
                )
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: WanderSpacing.space3) {
            Button(action: saveRecord) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                    Text(isSaved ? "저장 완료" : "기록 저장하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(isSaved ? WanderColors.success : WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
            .disabled(isSaved)

            Button(action: { showShareSheet = true }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .stroke(WanderColors.border, lineWidth: 1)
                )
            }
        }
        .padding(.top, WanderSpacing.space4)
    }

    // MARK: - Save Record
    private func saveRecord() {
        let record = TravelRecord(
            title: result.title,
            startDate: result.startDate,
            endDate: result.endDate
        )
        record.totalDistance = result.totalDistance
        record.placeCount = result.placeCount
        record.photoCount = result.photoCount

        // Create day
        let day = TravelDay(date: result.startDate, dayNumber: 1)

        // Create places
        for (index, cluster) in result.places.enumerated() {
            let place = Place(
                name: cluster.name,
                address: cluster.address,
                coordinate: cluster.coordinate,
                startTime: cluster.startTime
            )
            place.activityLabel = cluster.activityType.displayName
            place.placeType = cluster.placeType ?? "other"
            place.order = index

            day.places.append(place)
        }

        record.days.append(day)

        modelContext.insert(record)

        withAnimation {
            isSaved = true
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

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: WanderSpacing.space2) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(WanderColors.primary)

            Text(value)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(label)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
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
                // Number circle
                ZStack {
                    Circle()
                        .fill(place.activityType.color)
                        .frame(width: 36, height: 36)

                    Text(place.activityType.emoji)
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

                // Place name
                Text(place.name)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                // Address
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(1)
                }

                // Activity tag
                HStack(spacing: WanderSpacing.space1) {
                    Text(place.activityType.emoji)
                    Text(place.activityType.displayName)
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
                .padding(.horizontal, WanderSpacing.space2)
                .padding(.vertical, WanderSpacing.space1)
                .background(place.activityType.color)
                .cornerRadius(WanderSpacing.radiusSmall)

                // Photo count
                Text("사진 \(place.photos.count)장")
                    .font(WanderTypography.caption2)
                    .foregroundColor(WanderColors.textTertiary)
            }
            .padding(.bottom, isLast ? 0 : WanderSpacing.space4)

            Spacer()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet View (Placeholder)
struct ShareSheetView: View {
    let result: AnalysisResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space4) {
                Text("공유 옵션")
                    .font(WanderTypography.title2)

                // Share options will be implemented later
                Text("공유 기능은 Phase 3에서 구현됩니다")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }
            .padding()
            .navigationTitle("공유하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ResultView(
        result: AnalysisResult(),
        selectedAssets: []
    )
}
