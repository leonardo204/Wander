import SwiftUI
import MapKit
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ResultView")

struct ResultView: View {
    let result: AnalysisResult
    let selectedAssets: [PHAsset]
    var onSaveComplete: ((TravelRecord) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showShareSheet = false
    @State private var isSaved = false
    @State private var savedRecord: TravelRecord?

    init(result: AnalysisResult, selectedAssets: [PHAsset], onSaveComplete: ((TravelRecord) -> Void)? = nil) {
        self.result = result
        self.selectedAssets = selectedAssets
        self.onSaveComplete = onSaveComplete
        logger.info("📊 [ResultView] init - 제목: \(result.title), 장소: \(result.places.count)개")
    }

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
                        logger.info("📊 [ResultView] 닫기 버튼 클릭 - 저장됨: \(isSaved)")
                        if isSaved {
                            // 저장된 경우 애니메이션 없이 즉시 닫기
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                dismiss()
                            }
                        } else {
                            dismiss()
                        }
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
            .onAppear {
                logger.info("📊 [ResultView] onAppear - 화면 표시됨")
                logger.info("📊 [ResultView] result.title: \(result.title)")
                logger.info("📊 [ResultView] result.places.count: \(result.places.count)")
                logger.info("📊 [ResultView] result.photoCount: \(result.photoCount)")
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

        for place in result.places {
            let dateOnly = calendar.startOfDay(for: place.startTime)
            if grouped[dateOnly] == nil {
                grouped[dateOnly] = []
            }
            grouped[dateOnly]?.append(place)
        }

        return grouped
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
        record.photoCount = selectedAssets.count // Use actual selected count

        // Collect photos that are in clusters
        var savedPhotoIds = Set<String>()

        // Group clusters by date
        let calendar = Calendar.current
        var clustersByDate: [Date: [PlaceCluster]] = [:]

        for cluster in result.places {
            let dateOnly = calendar.startOfDay(for: cluster.startTime)
            if clustersByDate[dateOnly] == nil {
                clustersByDate[dateOnly] = []
            }
            clustersByDate[dateOnly]?.append(cluster)
        }

        // Sort dates and create days
        let sortedDates = clustersByDate.keys.sorted()
        logger.info("💾 [ResultView] 날짜별 분류: \(sortedDates.count)일")

        for (dayIndex, date) in sortedDates.enumerated() {
            let dayNumber = dayIndex + 1
            let day = TravelDay(date: date, dayNumber: dayNumber)

            guard let clustersForDay = clustersByDate[date] else { continue }

            // Sort clusters by time within the day
            let sortedClusters = clustersForDay.sorted { $0.startTime < $1.startTime }

            for (placeIndex, cluster) in sortedClusters.enumerated() {
                let place = Place(
                    name: cluster.name,
                    address: cluster.address,
                    coordinate: cluster.coordinate,
                    startTime: cluster.startTime
                )
                place.activityLabel = cluster.activityType.displayName
                place.placeType = cluster.placeType ?? "other"
                place.order = placeIndex

                // Save photos to place
                for (photoIndex, asset) in cluster.photos.enumerated() {
                    let photo = PhotoItem(
                        assetIdentifier: asset.localIdentifier,
                        capturedAt: asset.creationDate,
                        latitude: asset.location?.coordinate.latitude,
                        longitude: asset.location?.coordinate.longitude
                    )
                    photo.order = photoIndex
                    place.photos.append(photo)
                    savedPhotoIds.insert(asset.localIdentifier)
                }

                day.places.append(place)
            }

            record.days.append(day)
            logger.info("💾 [ResultView] Day \(dayNumber): \(sortedClusters.count)개 장소")
        }

        // Find photos not in any cluster (no GPS or filtered out)
        let uncategorizedAssets = selectedAssets.filter { !savedPhotoIds.contains($0.localIdentifier) }

        if !uncategorizedAssets.isEmpty {
            // Add to the last day or create new day if no days exist
            let lastDay: TravelDay
            if let existingLastDay = record.days.last {
                lastDay = existingLastDay
            } else {
                lastDay = TravelDay(date: result.startDate, dayNumber: 1)
                record.days.append(lastDay)
            }

            // Create "미분류" place for uncategorized photos
            let uncategorizedPlace = Place(
                name: "미분류 사진",
                address: "",
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                startTime: uncategorizedAssets.first?.creationDate ?? Date()
            )
            uncategorizedPlace.activityLabel = "기타"
            uncategorizedPlace.placeType = "other"
            uncategorizedPlace.order = lastDay.places.count

            for (photoIndex, asset) in uncategorizedAssets.enumerated() {
                let photo = PhotoItem(
                    assetIdentifier: asset.localIdentifier,
                    capturedAt: asset.creationDate,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
                photo.order = photoIndex
                uncategorizedPlace.photos.append(photo)
            }

            lastDay.places.append(uncategorizedPlace)
            record.placeCount += 1
            logger.info("💾 [ResultView] 미분류 사진 \(uncategorizedAssets.count)장 추가")
        }

        modelContext.insert(record)
        savedRecord = record

        logger.info("💾 [ResultView] 저장 완료 - 날짜: \(record.days.count)일, 장소: \(record.placeCount), 사진: \(selectedAssets.count)")

        withAnimation {
            isSaved = true
        }

        // 저장 후 1초 뒤 자동으로 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            logger.info("📊 [ResultView] 자동 닫기 - 저장된 기록으로 이동")
            if let record = savedRecord {
                onSaveComplete?(record)
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dismiss()
            }
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

// MARK: - Day Header
struct DayHeader: View {
    let dayNumber: Int
    let date: Date

    var body: some View {
        HStack(spacing: WanderSpacing.space3) {
            Text("Day \(dayNumber)")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.primary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space1)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusMedium)

            Text(formatDate(date))
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)

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

// MARK: - Share Format
enum ShareFormat: String, CaseIterable, Identifiable {
    case text
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "텍스트"
        case .image: return "이미지"
        }
    }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        }
    }

    var description: String {
        switch self {
        case .text: return "타임라인을 텍스트로 공유"
        case .image: return "1080×1920 세로형 이미지"
        }
    }
}

// MARK: - Share Sheet View (Format Selection → Preview → Share)
struct ShareSheetView: View {
    let result: AnalysisResult
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ShareFormat = .image
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space5) {
                // Header
                VStack(spacing: WanderSpacing.space2) {
                    Text("공유 형식 선택")
                        .font(WanderTypography.title3)
                        .foregroundColor(WanderColors.textPrimary)

                    Text("형식을 선택한 후 미리보기를 확인하세요")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                }
                .padding(.top, WanderSpacing.space4)

                // Format Selection
                VStack(spacing: WanderSpacing.space3) {
                    ForEach(ShareFormat.allCases) { format in
                        ShareFormatCard(
                            format: format,
                            isSelected: selectedFormat == format,
                            onSelect: { selectedFormat = format }
                        )
                    }
                }

                Spacer()

                // Next Button
                Button(action: { showPreview = true }) {
                    HStack {
                        Text("미리보기")
                        Image(systemName: "chevron.right")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
            }
            .padding(WanderSpacing.screenMargin)
            .navigationTitle("공유하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                SharePreviewView(result: result, format: selectedFormat, onDismissAll: { dismiss() })
            }
        }
    }
}

// MARK: - Share Format Card
struct ShareFormatCard: View {
    let format: ShareFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: WanderSpacing.space4) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? WanderColors.primary : WanderColors.surface)
                        .frame(width: 48, height: 48)

                    Image(systemName: format.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : WanderColors.textSecondary)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.title)
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(format.description)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(WanderColors.primary)
                } else {
                    Circle()
                        .stroke(WanderColors.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(WanderSpacing.space4)
            .background(isSelected ? WanderColors.primaryPale : WanderColors.surface)
            .cornerRadius(WanderSpacing.radiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                    .stroke(isSelected ? WanderColors.primary : WanderColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Preview View
struct SharePreviewView: View {
    let result: AnalysisResult
    let format: ShareFormat
    let onDismissAll: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("includeWatermark") private var includeWatermark = true

    @State private var isLoading = true
    @State private var previewImage: UIImage?
    @State private var previewText: String = ""
    @State private var isSharing = false

    var body: some View {
        VStack(spacing: 0) {
            // Preview Content
            ScrollView {
                VStack(spacing: WanderSpacing.space4) {
                    if isLoading {
                        loadingView
                    } else {
                        switch format {
                        case .text:
                            textPreview
                        case .image:
                            imagePreview
                        }
                    }
                }
                .padding(WanderSpacing.screenMargin)
            }

            // Bottom Bar
            VStack(spacing: WanderSpacing.space3) {
                // Watermark Toggle
                Toggle(isOn: $includeWatermark) {
                    HStack(spacing: WanderSpacing.space2) {
                        Image(systemName: "signature")
                            .foregroundColor(WanderColors.textSecondary)
                        Text("워터마크 포함")
                            .font(WanderTypography.body)
                    }
                }
                .tint(WanderColors.primary)
                .onChange(of: includeWatermark) { _, _ in
                    generatePreview()
                }

                // Share Button
                Button(action: performShare) {
                    HStack {
                        if isSharing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isSharing ? "공유 준비 중..." : "공유하기")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(isLoading || isSharing ? WanderColors.textTertiary : WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(isLoading || isSharing)
            }
            .padding(WanderSpacing.screenMargin)
            .background(WanderColors.surface)
        }
        .background(WanderColors.background)
        .navigationTitle("미리보기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("닫기") {
                    onDismissAll()
                }
                .foregroundColor(WanderColors.textSecondary)
            }
        }
        .onAppear {
            generatePreview()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer()
                .frame(height: 100)

            ProgressView()
                .scaleEffect(1.5)

            Text("미리보기 생성 중...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()
                .frame(height: 100)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Text Preview
    private var textPreview: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Format badge
            HStack {
                Image(systemName: "doc.text")
                Text("텍스트 미리보기")
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WanderColors.primaryPale)
            .cornerRadius(WanderSpacing.radiusMedium)

            // Text content
            Text(previewText)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(WanderColors.textPrimary)
                .padding(WanderSpacing.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .stroke(WanderColors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Image Preview
    private var imagePreview: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Format badge
            HStack {
                Image(systemName: "photo")
                Text("이미지 미리보기 (1080×1920)")
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WanderColors.primaryPale)
            .cornerRadius(WanderSpacing.radiusMedium)

            // Image content
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(WanderSpacing.radiusLarge)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
    }

    // MARK: - Generate Preview
    private func generatePreview() {
        isLoading = true

        Task.detached(priority: .userInitiated) {
            switch format {
            case .text:
                let text = ExportService.shared.exportAsText(result: result, includeWatermark: includeWatermark)
                await MainActor.run {
                    previewText = text
                    isLoading = false
                }

            case .image:
                let image = await ExportService.shared.exportAsImage(result: result, includeWatermark: includeWatermark)
                await MainActor.run {
                    previewImage = image
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Perform Share
    private func performShare() {
        isSharing = true
        logger.info("📤 [SharePreview] 공유 시작 - 형식: \(format.title)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var items: [Any] = []

            switch format {
            case .text:
                items = [previewText]
            case .image:
                if let image = previewImage {
                    items = [image]
                }
            }

            guard !items.isEmpty else {
                isSharing = false
                return
            }

            showActivitySheet(with: items)
        }
    }

    private func showActivitySheet(with items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            isSharing = false
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            isSharing = false
            if completed {
                logger.info("📤 [SharePreview] 공유 완료")
                onDismissAll()
            }
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.maxY - 100, width: 0, height: 0)
            popover.permittedArrowDirections = .down
        }

        topVC.present(activityVC, animated: true) {
            logger.info("📤 [SharePreview] Activity sheet 표시됨")
        }
    }
}

// MARK: - Activity View Controller (UIKit Wrapper)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ResultView(
        result: AnalysisResult(),
        selectedAssets: []
    )
}
