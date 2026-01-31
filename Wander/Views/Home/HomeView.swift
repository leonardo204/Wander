import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "HomeView")

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TravelRecord.createdAt, order: .reverse) private var records: [TravelRecord]
    @State private var showPhotoSelection = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    // Quick Action Cards
                    quickActionSection

                    // Recent Records Section
                    recentRecordsSection
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.top, WanderSpacing.space4)
            }
            .background(WanderColors.background)
            .navigationTitle("Wander")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Wander")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(WanderColors.primary)
                }
            }
            .sheet(isPresented: $showPhotoSelection) {
                PhotoSelectionView()
            }
            .onAppear {
                logger.info("🏠 [HomeView] 나타남 - 저장된 기록: \(records.count)개")
                for (index, record) in records.prefix(5).enumerated() {
                    logger.info("🏠 [HomeView] 기록[\(index)]: \(record.title), days: \(record.days.count), places: \(record.placeCount)")
                }
            }
        }
    }

    // MARK: - Quick Action Section
    private var quickActionSection: some View {
        HStack(spacing: WanderSpacing.space4) {
            QuickActionCard(
                icon: "camera.fill",
                title: "새 여행 기록하기",
                subtitle: "사진으로 여행 기록",
                backgroundColor: WanderColors.primaryPale
            ) {
                showPhotoSelection = true
            }

            QuickActionCard(
                icon: "map.fill",
                title: "지도에서 보기",
                subtitle: "여행 발자취",
                backgroundColor: WanderColors.primaryPale
            ) {
                // TODO: Navigate to map view
            }
        }
    }

    // MARK: - Recent Records Section
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("최근 기록")
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            if records.isEmpty {
                emptyStateView
            } else {
                recentRecordsList
            }
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()
                .frame(height: WanderSpacing.space8)

            // Route Illustration
            RouteIllustration()
                .frame(height: 150)

            VStack(spacing: WanderSpacing.space2) {
                Text("아직 기록이 없어요")
                    .font(WanderTypography.title3)
                    .foregroundColor(WanderColors.textPrimary)

                Text("첫 번째 여행을 기록해 보세요")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Button(action: {
                showPhotoSelection = true
            }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "plus")
                    Text("여행 기록 만들기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
            .padding(.top, WanderSpacing.space4)

            Spacer()
                .frame(height: WanderSpacing.space8)
        }
    }

    // MARK: - Recent Records List
    private var recentRecordsList: some View {
        LazyVStack(spacing: WanderSpacing.space4) {
            ForEach(records.prefix(5)) { record in
                NavigationLink(destination: RecordDetailFullView(record: record)) {
                    RecordCard(record: record)
                }
                .buttonStyle(.plain)
                .onAppear {
                    logger.info("🏠 [HomeView] RecordCard 표시: \(record.title)")
                }
            }
        }
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: WanderSpacing.space3) {
                // Icon Area
                RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                    .fill(WanderColors.surface)
                    .frame(height: 80)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 32))
                            .foregroundColor(WanderColors.primary)
                    )

                // Text Area
                VStack(alignment: .leading, spacing: WanderSpacing.space1) {
                    Text(title)
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(subtitle)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(WanderSpacing.space4)
            .background(backgroundColor)
            .cornerRadius(WanderSpacing.radiusLarge)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Record Card
struct RecordCard: View {
    let record: TravelRecord

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                .fill(WanderColors.primaryPale)
                .frame(height: 120)
                .overlay(
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(WanderColors.primary)
                )

            VStack(alignment: .leading, spacing: WanderSpacing.space1) {
                Text(record.title)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Text(formatDateRange(start: record.startDate, end: record.endDate))
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)

                HStack(spacing: WanderSpacing.space4) {
                    Label("\(record.placeCount)곳", systemImage: "mappin")
                    Label("\(Int(record.totalDistance))km", systemImage: "car.fill")
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusXXL)
        .elevation1()
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }
}

// MARK: - Route Illustration
struct RouteIllustration: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Dashed path
                Path { path in
                    path.move(to: CGPoint(x: width * 0.2, y: height * 0.8))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.5, y: height * 0.3),
                        control: CGPoint(x: width * 0.3, y: height * 0.5)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.8, y: height * 0.7),
                        control: CGPoint(x: width * 0.7, y: height * 0.2)
                    )
                }
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundColor(WanderColors.border)

                // Pin marker
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(WanderColors.primary)
                    .position(x: width * 0.5, y: height * 0.25)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
