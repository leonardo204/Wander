import SwiftUI
import SwiftData
import MapKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "SharedRecordView")

/// 공유받은 기록 데이터 모델
struct SharedRecordData: Codable {
    let title: String
    let startDate: Date
    let endDate: Date
    let places: [SharedPlaceData]
    let totalDistance: Double
    let photoCount: Int
    let aiStory: String?

    struct SharedPlaceData: Codable, Identifiable {
        var id: String { "\(latitude)-\(longitude)-\(name)" }
        let name: String
        let address: String
        let latitude: Double
        let longitude: Double
        let activityType: String
        let visitTime: Date
        let photoCount: Int
    }

    /// Base64 인코딩
    func encode() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }

    /// Base64 디코딩
    static func decode(from base64String: String) -> SharedRecordData? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return try? JSONDecoder().decode(SharedRecordData.self, from: data)
    }
}

/// 공유받은 기록 보기 화면
struct SharedRecordView: View {
    let sharedData: SharedRecordData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showSaveConfirmation = false
    @State private var isSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    // Header
                    headerSection

                    // Map Section
                    mapSection

                    // Stats Section
                    statsSection

                    // Timeline Section
                    timelineSection

                    // AI Story (if available)
                    if let story = sharedData.aiStory, !story.isEmpty {
                        storySection(story)
                    }

                    // Action Buttons
                    actionButtons
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }
            .background(WanderColors.background)
            .navigationTitle("공유받은 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .confirmationDialog(
                "이 기록을 내 기록으로 저장하시겠습니까?",
                isPresented: $showSaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("저장") {
                    saveToMyRecords()
                }
            } message: {
                Text("저장된 기록은 '기록' 탭에서 확인할 수 있습니다.")
            }
        }
        .onAppear {
            logger.info("📥 [SharedRecordView] 공유 기록 열림 - \(sharedData.title)")
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space2) {
            Text(sharedData.title)
                .font(WanderTypography.title1)
                .foregroundColor(WanderColors.textPrimary)

            Text(formatDateRange(sharedData.startDate, sharedData.endDate))
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            // Shared Badge
            HStack(spacing: WanderSpacing.space1) {
                Image(systemName: "link")
                Text("공유받은 기록")
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.primary)
            .padding(.horizontal, WanderSpacing.space3)
            .padding(.vertical, WanderSpacing.space1)
            .background(WanderColors.primaryPale)
            .cornerRadius(WanderSpacing.radiusMedium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Text("여행 동선")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            Map {
                ForEach(Array(sharedData.places.enumerated()), id: \.element.id) { index, place in
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)) {
                        SharedPlaceMarker(number: index + 1)
                    }
                }

                if sharedData.places.count > 1 {
                    MapPolyline(coordinates: sharedData.places.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(WanderColors.primary, lineWidth: 3)
                }
            }
            .frame(height: 200)
            .cornerRadius(WanderSpacing.radiusLarge)
            .disabled(true)
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: WanderSpacing.space4) {
            SharedStatCard(
                icon: "mappin.circle.fill",
                value: "\(sharedData.places.count)",
                label: "방문 장소"
            )

            SharedStatCard(
                icon: "car.fill",
                value: String(format: "%.1f", sharedData.totalDistance),
                label: "이동 거리 (km)"
            )

            SharedStatCard(
                icon: "photo.fill",
                value: "\(sharedData.photoCount)",
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

            ForEach(Array(sharedData.places.enumerated()), id: \.element.id) { index, place in
                SharedTimelineCard(
                    place: place,
                    index: index,
                    isLast: index == sharedData.places.count - 1
                )
            }
        }
    }

    // MARK: - Story Section
    private func storySection(_ story: String) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(WanderColors.primary)
                Text("AI 스토리")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)
            }

            Text(story)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .padding(WanderSpacing.space4)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: WanderSpacing.space3) {
            Button(action: { showSaveConfirmation = true }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                    Text(isSaved ? "저장 완료" : "내 기록으로 저장")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(isSaved ? WanderColors.success : WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
            .disabled(isSaved)
        }
        .padding(.top, WanderSpacing.space4)
    }

    // MARK: - Helpers
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        // 같은 날이면 하나만 표시
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    private func saveToMyRecords() {
        logger.info("💾 [SharedRecordView] 공유 기록 저장 시작")

        let record = TravelRecord(
            title: sharedData.title,
            startDate: sharedData.startDate,
            endDate: sharedData.endDate
        )
        record.totalDistance = sharedData.totalDistance
        record.placeCount = sharedData.places.count
        record.photoCount = sharedData.photoCount
        record.aiStory = sharedData.aiStory

        let day = TravelDay(date: sharedData.startDate, dayNumber: 1)

        for (index, sharedPlace) in sharedData.places.enumerated() {
            let place = Place(
                name: sharedPlace.name,
                address: sharedPlace.address,
                coordinate: CLLocationCoordinate2D(
                    latitude: sharedPlace.latitude,
                    longitude: sharedPlace.longitude
                ),
                startTime: sharedPlace.visitTime
            )
            place.activityLabel = sharedPlace.activityType
            place.order = index
            day.places.append(place)
        }

        record.days.append(day)
        modelContext.insert(record)

        logger.info("💾 [SharedRecordView] 공유 기록 저장 완료")
        withAnimation {
            isSaved = true
        }
    }
}

// MARK: - Shared Place Marker
struct SharedPlaceMarker: View {
    let number: Int

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

// MARK: - Shared Stat Card
struct SharedStatCard: View {
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

// MARK: - Shared Timeline Card
struct SharedTimelineCard: View {
    let place: SharedRecordData.SharedPlaceData
    let index: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: WanderSpacing.space4) {
            // Timeline indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(WanderColors.primary)
                        .frame(width: 36, height: 36)

                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                if !isLast {
                    Rectangle()
                        .fill(WanderColors.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                Text(formatTime(place.visitTime))
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)

                Text(place.name)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                if !place.address.isEmpty {
                    Text(place.address)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(1)
                }

                Text("📸 사진 \(place.photoCount)장")
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

#Preview {
    let sampleData = SharedRecordData(
        title: "제주도 여행",
        startDate: Date(),
        endDate: Date(),
        places: [
            SharedRecordData.SharedPlaceData(
                name: "제주공항",
                address: "제주시 공항로",
                latitude: 33.5066,
                longitude: 126.4924,
                activityType: "airport",
                visitTime: Date(),
                photoCount: 3
            )
        ],
        totalDistance: 45.2,
        photoCount: 24,
        aiStory: "오늘 제주도로 떠났다..."
    )

    SharedRecordView(sharedData: sampleData)
}
