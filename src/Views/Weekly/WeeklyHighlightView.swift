import SwiftUI
import Photos
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "WeeklyHighlightView")

/// "이번 주 하이라이트" 뷰
struct WeeklyHighlightView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weeklyPhotos: [DayPhotos] = []
    @State private var isLoading = true
    @State private var selectedAssets: Set<String> = []
    @State private var showAnalyzing = false
    @State private var analysisResult: WeeklyResult?
    @State private var showResult = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if weeklyPhotos.isEmpty || weeklyPhotos.allSatisfy({ $0.photos.isEmpty }) {
                    emptyStateView
                } else {
                    photoSelectionView
                }

                // Bottom action bar
                if !selectedAssets.isEmpty {
                    actionBar
                }
            }
            .background(WanderColors.background)
            .navigationTitle("이번 주 하이라이트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .onAppear {
                logger.info("📅 [Weekly] 화면 나타남")
                loadWeeklyPhotos()
            }
            .fullScreenCover(isPresented: $showAnalyzing) {
                WeeklyAnalyzingView(
                    weeklyPhotos: weeklyPhotos,
                    selectedAssets: selectedAssets,
                    onComplete: { result in
                        logger.info("📅 [Weekly] 분석 완료 - 결과 수신")
                        self.analysisResult = result
                        self.showAnalyzing = false
                        // fullScreenCover 닫힌 후 sheet 열기 (딜레이 필요)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            logger.info("📅 [Weekly] 결과 화면 표시")
                            self.showResult = true
                        }
                    },
                    onCancel: {
                        logger.info("📅 [Weekly] 분석 취소")
                        self.showAnalyzing = false
                    }
                )
            }
            .sheet(isPresented: $showResult) {
                if let result = analysisResult {
                    WeeklyResultView(result: result)
                } else {
                    Text("결과를 불러올 수 없습니다")
                        .onAppear {
                            logger.error("📅 [Weekly] 결과 없음 - sheet 닫기")
                            showResult = false
                        }
                }
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("이번 주 사진을 불러오는 중...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.textTertiary)

            Text("이번 주 GPS가 포함된\n사진이 없어요")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("위치 정보가 포함된 사진을 촬영해 보세요")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Photo Selection View
    private var photoSelectionView: some View {
        VStack(spacing: 0) {
            // Week header
            weekHeader
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space3)
                .background(WanderColors.surface)

            ScrollView {
                LazyVStack(spacing: WanderSpacing.space4) {
                    ForEach(weeklyPhotos, id: \.dayName) { dayPhotos in
                        DayPhotoSection(
                            dayPhotos: dayPhotos,
                            selectedAssets: $selectedAssets
                        )
                    }
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }
        }
    }

    // MARK: - Week Header
    private var weekHeader: some View {
        let totalPhotos = weeklyPhotos.flatMap { $0.photos }.count
        let gpsPhotos = weeklyPhotos.flatMap { $0.photos }.filter { $0.location != nil }.count

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(weekRangeText)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Text("GPS 있는 사진 \(gpsPhotos)장 / 전체 \(totalPhotos)장")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Spacer()

            Button(selectedAssets.count == gpsPhotos ? "선택 해제" : "전체 선택") {
                if selectedAssets.count == gpsPhotos {
                    selectedAssets.removeAll()
                } else {
                    let gpsAssets = weeklyPhotos.flatMap { $0.photos }.filter { $0.location != nil }
                    selectedAssets = Set(gpsAssets.map { $0.localIdentifier })
                }
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.primary)
        }
    }

    private var weekRangeText: String {
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return ""
        }
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? now

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"

        return "\(formatter.string(from: weekStart)) ~ \(formatter.string(from: weekEnd))"
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Text("\(selectedAssets.count)장 선택됨")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                Button(action: { showAnalyzing = true }) {
                    Text("분석하기")
                        .font(WanderTypography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, WanderSpacing.space6)
                        .padding(.vertical, WanderSpacing.space3)
                        .background(WanderColors.primary)
                        .cornerRadius(WanderSpacing.radiusFull)
                }
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
        }
    }

    // MARK: - Load Weekly Photos
    private func loadWeeklyPhotos() {
        logger.info("📅 [Weekly] 이번 주 사진 로드 시작")

        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            isLoading = false
            return
        }

        var dayPhotosList: [DayPhotos] = []
        let dayNames = ["월", "화", "수", "목", "금", "토", "일"]

        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayDate) ?? dayDate

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            fetchOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate < %@",
                dayDate as NSDate,
                nextDay as NSDate
            )

            let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            var assets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }

            let dayName = dayNames[dayOffset]
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            let dateString = formatter.string(from: dayDate)

            dayPhotosList.append(DayPhotos(
                dayName: "\(dayName)요일 (\(dateString))",
                date: dayDate,
                photos: assets
            ))

            logger.info("📅 [Weekly] \(dayName)요일: \(assets.count)장")
        }

        DispatchQueue.main.async {
            self.weeklyPhotos = dayPhotosList

            // Auto-select GPS photos
            let gpsAssets = dayPhotosList.flatMap { $0.photos }.filter { $0.location != nil }
            self.selectedAssets = Set(gpsAssets.map { $0.localIdentifier })

            self.isLoading = false
        }
    }
}

// MARK: - Day Photos Model
struct DayPhotos {
    let dayName: String
    let date: Date
    let photos: [PHAsset]
}

// MARK: - Day Photo Section
struct DayPhotoSection: View {
    let dayPhotos: DayPhotos
    @Binding var selectedAssets: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space2) {
            // Day header
            HStack {
                Text(dayPhotos.dayName)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                if !dayPhotos.photos.isEmpty {
                    let gpsCount = dayPhotos.photos.filter { $0.location != nil }.count
                    Text("\(gpsCount)/\(dayPhotos.photos.count)장")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }
            }

            if dayPhotos.photos.isEmpty {
                Text("사진 없음")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)
                    .padding(.vertical, WanderSpacing.space2)
            } else {
                // Photo grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4)
                ], spacing: 4) {
                    ForEach(dayPhotos.photos.filter { $0.location != nil }, id: \.localIdentifier) { asset in
                        WeeklyPhotoCell(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset.localIdentifier)
                        ) {
                            if selectedAssets.contains(asset.localIdentifier) {
                                selectedAssets.remove(asset.localIdentifier)
                            } else {
                                selectedAssets.insert(asset.localIdentifier)
                            }
                        }
                    }
                }
            }
        }
        .padding(WanderSpacing.space3)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }
}

// MARK: - Weekly Photo Cell
struct WeeklyPhotoCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 60, maxHeight: 60)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(WanderColors.primaryPale)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 60, maxHeight: 60)
                }

                if isSelected {
                    Rectangle()
                        .fill(WanderColors.primary.opacity(0.3))

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(WanderColors.primary)
                        .padding(2)
                }
            }
            .cornerRadius(WanderSpacing.radiusSmall)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            self.thumbnail = image
        }
    }
}

// MARK: - Weekly Result Model
struct WeeklyResult {
    var dateRange: String
    var daySummaries: [DaySummary]
    var totalDistance: Double
    var placeCount: Int
    var photoCount: Int
    var keywords: [String]
}

struct DaySummary {
    var dayName: String
    var summary: String
    var hasData: Bool
}

// MARK: - Weekly Analyzing View
struct WeeklyAnalyzingView: View {
    let weeklyPhotos: [DayPhotos]
    let selectedAssets: Set<String>
    let onComplete: (WeeklyResult) -> Void
    let onCancel: () -> Void

    @State private var progress: Double = 0
    @State private var currentStep = "분석 준비 중..."

    var body: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(WanderColors.primaryPale, lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(WanderColors.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                Image(systemName: "calendar")
                    .font(.system(size: 32))
                    .foregroundColor(WanderColors.primary)
            }

            VStack(spacing: WanderSpacing.space2) {
                Text("주간 분석 중...")
                    .font(WanderTypography.title3)
                    .foregroundColor(WanderColors.textPrimary)

                Text(currentStep)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Spacer()

            Button("취소") {
                onCancel()
            }
            .foregroundColor(WanderColors.textSecondary)
            .padding(.bottom, WanderSpacing.space8)
        }
        .background(WanderColors.background)
        .task {
            await analyze()
        }
    }

    private func analyze() async {
        let dayNames = ["월", "화", "수", "목", "금", "토", "일"]
        var daySummaries: [DaySummary] = []
        var allPlaces: Set<String> = []
        var keywords: Set<String> = []

        for (index, dayPhotos) in weeklyPhotos.enumerated() {
            currentStep = "\(dayNames[index])요일 분석 중..."
            progress = Double(index + 1) / Double(weeklyPhotos.count + 1)

            try? await Task.sleep(nanoseconds: 200_000_000)

            let selectedDayAssets = dayPhotos.photos.filter { selectedAssets.contains($0.localIdentifier) }

            if selectedDayAssets.isEmpty {
                daySummaries.append(DaySummary(
                    dayName: "\(dayNames[index])요일",
                    summary: "GPS 기록 없음",
                    hasData: false
                ))
                continue
            }

            // Get place names via reverse geocoding
            var placeName = "활동"
            if let firstAsset = selectedDayAssets.first,
               let location = firstAsset.location {
                let geocoder = CLGeocoder()
                if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
                   let placemark = placemarks.first {
                    placeName = placemark.name ?? placemark.subLocality ?? "활동"
                    if let locality = placemark.locality {
                        allPlaces.insert(locality)
                    }
                }
            }

            let summary = "\(placeName) 등 \(selectedDayAssets.count)곳"
            daySummaries.append(DaySummary(
                dayName: "\(dayNames[index])요일",
                summary: summary,
                hasData: true
            ))
        }

        currentStep = "결과 생성 중..."
        progress = 1.0

        // Generate keywords
        keywords = Set(["일상", "주간"])
        if allPlaces.count > 0 {
            keywords.insert("여행")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"

        let result = WeeklyResult(
            dateRange: weeklyPhotos.isEmpty ? "" : "\(formatter.string(from: weeklyPhotos.first!.date)) ~ \(formatter.string(from: weeklyPhotos.last!.date))",
            daySummaries: daySummaries,
            totalDistance: 0, // Could calculate based on GPS
            placeCount: allPlaces.count,
            photoCount: selectedAssets.count,
            keywords: Array(keywords)
        )

        try? await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            onComplete(result)
        }
    }
}

// MARK: - Weekly Result View
struct WeeklyResultView: View {
    let result: WeeklyResult
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space5) {
                    // Header
                    headerSection

                    // Day summaries
                    daySummariesSection

                    // Stats
                    statsSection

                    // Keywords
                    if !result.keywords.isEmpty {
                        keywordsSection
                    }

                    // Share button
                    shareButton
                }
                .padding(WanderSpacing.screenMargin)
            }
            .background(WanderColors.background)
            .navigationTitle("주간 요약")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [generateShareText()])
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: WanderSpacing.space2) {
            Text("이번 주 하이라이트")
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(result.dateRange)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
        }
    }

    private var daySummariesSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            ForEach(result.daySummaries, id: \.dayName) { day in
                HStack {
                    Text(day.dayName)
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textPrimary)
                        .frame(width: 60, alignment: .leading)

                    Text(day.summary)
                        .font(WanderTypography.body)
                        .foregroundColor(day.hasData ? WanderColors.textSecondary : WanderColors.textTertiary)

                    Spacer()
                }
                .padding(.vertical, WanderSpacing.space2)

                if day.dayName != result.daySummaries.last?.dayName {
                    Divider()
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    private var statsSection: some View {
        HStack(spacing: WanderSpacing.space4) {
            WeeklyStatCard(icon: "mappin.circle.fill", value: "\(result.placeCount)", label: "장소")
            WeeklyStatCard(icon: "photo.fill", value: "\(result.photoCount)", label: "사진")
        }
    }

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space2) {
            Text("이번 주 키워드")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            HStack(spacing: WanderSpacing.space2) {
                ForEach(result.keywords, id: \.self) { keyword in
                    Text("#\(keyword)")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.primary)
                        .padding(.horizontal, WanderSpacing.space3)
                        .padding(.vertical, WanderSpacing.space2)
                        .background(WanderColors.primaryPale)
                        .cornerRadius(WanderSpacing.radiusFull)
                }
            }
        }
    }

    private var shareButton: some View {
        Button(action: { showShareSheet = true }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("공유하기")
            }
            .font(WanderTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: WanderSpacing.buttonHeight)
            .background(WanderColors.primary)
            .cornerRadius(WanderSpacing.radiusLarge)
        }
    }

    private func generateShareText() -> String {
        var text = "📅 이번 주 하이라이트 (\(result.dateRange))\n\n"

        for day in result.daySummaries {
            text += "\(day.dayName): \(day.summary)\n"
        }

        text += "\n📍 방문장소: \(result.placeCount)곳\n"
        text += "📸 사진: \(result.photoCount)장\n"

        if !result.keywords.isEmpty {
            text += "\n\(result.keywords.map { "#\($0)" }.joined(separator: " "))"
        }

        return text
    }
}

// MARK: - Weekly Stat Card
struct WeeklyStatCard: View {
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

// MARK: - Share Sheet (UIKit Wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    WeeklyHighlightView()
}
