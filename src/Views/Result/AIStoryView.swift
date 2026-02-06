import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "AIStoryView")

struct AIStoryView: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedProvider: AIProvider?
    @State private var isGenerating = false
    @State private var generatedStory: String?
    @State private var errorMessage: String?
    @State private var showProviderSelection = false

    private var hasConfiguredProvider: Bool {
        GoogleOAuthService.shared.isAuthenticated ||
        AIProvider.allCases.contains { provider in
            KeychainManager.shared.hasAPIKey(for: provider.keychainType)
        }
    }

    private var configuredProviders: [AIProvider] {
        var providers = AIProvider.allCases.filter { provider in
            KeychainManager.shared.hasAPIKey(for: provider.keychainType)
        }
        if GoogleOAuthService.shared.isAuthenticated && !providers.contains(.google) {
            providers.append(.google)
        }
        return providers
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    if !hasConfiguredProvider {
                        noAPIKeyView
                    } else if isGenerating {
                        generatingView
                    } else if let story = generatedStory {
                        storyResultView(story: story)
                    } else if let error = errorMessage {
                        errorView(message: error)
                    } else {
                        readyToGenerateView
                    }
                }
                .padding(WanderSpacing.screenMargin)
            }
            .background(WanderColors.background)
            .navigationTitle("AI 스토리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }

                if generatedStory != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("저장") {
                            saveStory()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                logger.info("✨ [AIStoryView] AI 스토리 화면 나타남 - hasConfiguredProvider: \(hasConfiguredProvider)")
            }
            .sheet(isPresented: $showProviderSelection) {
                ProviderSelectionSheet(
                    providers: configuredProviders,
                    selectedProvider: $selectedProvider,
                    onConfirm: {
                        showProviderSelection = false
                        if selectedProvider != nil {
                            generateStory()
                        }
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - No API Key View

    private var noAPIKeyView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.warning)

            Text("API 키가 필요합니다")
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text("AI 스토리 생성을 위해 API 키를 설정해 주세요.\n설정 > AI 설정에서 키를 입력할 수 있습니다.")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                // Navigate to settings
                dismiss()
            }) {
                Text("설정으로 이동")
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
            }
            .padding(.top, WanderSpacing.space4)
        }
    }

    // MARK: - Ready to Generate View

    private var readyToGenerateView: some View {
        VStack(spacing: WanderSpacing.space6) {
            // Header
            VStack(spacing: WanderSpacing.space3) {
                ZStack {
                    Circle()
                        .fill(WanderColors.primaryPale)
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundColor(WanderColors.primary)
                }

                Text("AI 스토리 생성")
                    .font(WanderTypography.title2)
                    .foregroundColor(WanderColors.textPrimary)

                Text("여행 데이터를 바탕으로\n감성적인 스토리를 작성해 드립니다")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Travel Summary
            VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                Text("여행 정보")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                VStack(spacing: WanderSpacing.space2) {
                    SummaryRow(label: "제목", value: record.title)
                    SummaryRow(label: "기간", value: formatDateRange())
                    SummaryRow(label: "장소", value: "\(record.placeCount)곳")
                    SummaryRow(label: "이동 거리", value: String(format: "%.1fkm", record.totalDistance))
                    SummaryRow(label: "사진", value: "\(record.photoCount)장")
                }
                .padding(WanderSpacing.space4)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)
            }

            // Provider Selection
            VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                Text("AI 프로바이더")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)

                Button(action: { showProviderSelection = true }) {
                    HStack {
                        Text(selectedProvider?.displayName ?? "프로바이더 선택")
                            .foregroundColor(selectedProvider != nil ? WanderColors.textPrimary : WanderColors.textTertiary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .foregroundColor(WanderColors.textTertiary)
                    }
                    .padding(WanderSpacing.space4)
                    .background(WanderColors.surface)
                    .cornerRadius(WanderSpacing.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                            .stroke(WanderColors.border, lineWidth: 1)
                    )
                }
            }

            // Generate Button
            Button(action: {
                if selectedProvider != nil {
                    generateStory()
                } else {
                    showProviderSelection = true
                }
            }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "sparkles")
                    Text("스토리 생성하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }

            // Privacy Notice
            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(WanderColors.success)

                Text("장소명과 시간 정보만 전송됩니다. 사진은 전송되지 않습니다.")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }
            .padding(WanderSpacing.space3)
            .background(WanderColors.successBackground)
            .cornerRadius(WanderSpacing.radiusMedium)
        }
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()
                .frame(height: 60)

            ZStack {
                Circle()
                    .stroke(WanderColors.primaryPale, lineWidth: 6)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(WanderColors.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .modifier(RotatingModifier())

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(WanderColors.primary)
            }

            VStack(spacing: WanderSpacing.space2) {
                Text("스토리 생성 중...")
                    .font(WanderTypography.title3)
                    .foregroundColor(WanderColors.textPrimary)

                Text("AI가 여행 스토리를 작성하고 있습니다")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }
        }
    }

    // MARK: - Story Result View

    private func storyResultView(story: String) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space5) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(WanderColors.primary)
                Text("AI 스토리")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                Text(selectedProvider?.displayName ?? "")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)
            }

            // Story Content
            Text(story)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textPrimary)
                .lineSpacing(6)
                .padding(WanderSpacing.space4)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusLarge)

            // Actions
            HStack(spacing: WanderSpacing.space3) {
                Button(action: { regenerateStory() }) {
                    HStack(spacing: WanderSpacing.space1) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("다시 생성")
                    }
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
                    .padding(.horizontal, WanderSpacing.space4)
                    .padding(.vertical, WanderSpacing.space2)
                    .background(WanderColors.surface)
                    .cornerRadius(WanderSpacing.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                            .stroke(WanderColors.border, lineWidth: 1)
                    )
                }

                Button(action: { copyToClipboard(story) }) {
                    HStack(spacing: WanderSpacing.space1) {
                        Image(systemName: "doc.on.doc")
                        Text("복사")
                    }
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
                    .padding(.horizontal, WanderSpacing.space4)
                    .padding(.vertical, WanderSpacing.space2)
                    .background(WanderColors.surface)
                    .cornerRadius(WanderSpacing.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                            .stroke(WanderColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.warning)

            Text("생성 실패")
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(message)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: { regenerateStory() }) {
                Text("다시 시도")
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
            }
            .padding(.top, WanderSpacing.space4)
        }
    }

    // MARK: - Actions

    private func generateStory() {
        guard let provider = selectedProvider else {
            logger.warning("✨ [AIStoryView] 프로바이더 미선택")
            return
        }

        logger.info("✨ [AIStoryView] 스토리 생성 시작 - provider: \(provider.displayName)")
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let service = AIServiceFactory.createService(for: provider)
                let input = buildTravelStoryInput()
                logger.info("✨ [AIStoryView] AI 서비스 호출 - places: \(input.places.count)개")
                let story = try await service.generateStory(from: input)

                await MainActor.run {
                    logger.info("✨ [AIStoryView] 스토리 생성 성공 - length: \(story.count)자")
                    generatedStory = story
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    logger.error("✨ [AIStoryView] 스토리 생성 실패: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func regenerateStory() {
        logger.info("✨ [AIStoryView] 스토리 재생성 요청")
        generatedStory = nil
        errorMessage = nil
        generateStory()
    }

    private func saveStory() {
        guard let story = generatedStory else { return }
        logger.info("✨ [AIStoryView] 스토리 저장")
        record.aiStory = story
        try? modelContext.save()
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func buildTravelStoryInput() -> TravelStoryInput {
        var places: [TravelStoryInput.PlaceSummary] = []

        for day in record.days {
            for place in day.places {
                places.append(TravelStoryInput.PlaceSummary(
                    name: place.name,
                    address: place.address,
                    activityType: place.activityLabel,
                    visitTime: place.startTime,
                    photoCount: place.photos.count
                ))
            }
        }

        return TravelStoryInput(
            title: record.title,
            startDate: record.startDate,
            endDate: record.endDate,
            places: places,
            totalDistance: record.totalDistance,
            photoCount: record.photoCount
        )
    }

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        // 같은 날이면 하나만 표시
        if Calendar.current.isDate(record.startDate, inSameDayAs: record.endDate) {
            return formatter.string(from: record.startDate)
        }
        return "\(formatter.string(from: record.startDate)) ~ \(formatter.string(from: record.endDate))"
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()

            Text(value)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textPrimary)
        }
    }
}

// MARK: - Provider Selection Sheet

private struct ProviderSelectionSheet: View {
    let providers: [AIProvider]
    @Binding var selectedProvider: AIProvider?
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(providers) { provider in
                    Button(action: {
                        selectedProvider = provider
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textPrimary)

                                Text(provider.description)
                                    .font(WanderTypography.caption1)
                                    .foregroundColor(WanderColors.textSecondary)
                            }

                            Spacer()

                            if selectedProvider == provider {
                                Image(systemName: "checkmark")
                                    .foregroundColor(WanderColors.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("프로바이더 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("확인") { onConfirm() }
                        .disabled(selectedProvider == nil)
                }
            }
        }
    }
}

// MARK: - Rotating Modifier

private struct RotatingModifier: ViewModifier {
    @State private var isRotating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                .linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
    }
}

#Preview {
    AIStoryView(record: TravelRecord(title: "제주도 여행", startDate: Date(), endDate: Date()))
}
