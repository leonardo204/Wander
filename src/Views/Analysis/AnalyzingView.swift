import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "AnalyzingView")

struct AnalyzingView: View {
    @ObservedObject var viewModel: PhotoSelectionViewModel
    var onSaveComplete: ((TravelRecord) -> Void)?

    @State private var engine = AnalysisEngine()
    @State private var navigateToResult = false
    @State private var analysisResult: AnalysisResult?
    @State private var errorMessage: String?
    @State private var hasStartedAnalysis = false  // 중복 분석 방지
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space8) {
                Spacer()

                if let error = errorMessage {
                    errorView(message: error)
                } else if !navigateToResult {
                    progressView
                }

                Spacer()

                if !navigateToResult {
                    privacyBadge
                }
            }
            .padding(WanderSpacing.screenMargin)
            .background(WanderColors.background)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !navigateToResult {
                        Button("common.cancel".localized) {
                            dismiss()
                        }
                        .foregroundColor(WanderColors.textSecondary)
                    }
                }
            }
            .task {
                await startAnalysis()
            }
            .navigationDestination(isPresented: $navigateToResult) {
                if let result = analysisResult {
                    ResultView(
                        result: result,
                        selectedAssets: viewModel.selectedAssets,
                        onSaveComplete: { savedRecord in
                            logger.info("📱 [AnalyzingView] 저장 완료 콜백 받음: \(savedRecord.title)")
                            onSaveComplete?(savedRecord)
                            // ResultView를 먼저 닫고 (navigateToResult = false)
                            navigateToResult = false
                            // 그 다음 상위 뷰에서 닫도록 플래그 설정
                            viewModel.shouldDismissPhotoSelection = true
                            // 약간의 지연 후 AnalyzingView도 닫기 (상위 뷰가 플래그를 인식할 시간)
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
                                dismiss()
                            }
                        },
                        onDismiss: {
                            // ResultView에서 뒤로가기 시 모든 화면 닫기
                            logger.info("📱 ResultView 닫힘 → 모든 화면 즉시 닫기")
                            navigateToResult = false
                            viewModel.shouldDismissPhotoSelection = true
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
                                dismiss()
                            }
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    .onAppear {
                        logger.info("📱 ResultView 표시됨 - places: \(result.places.count), photos: \(result.photoCount), context: \(result.context.emoji) \(result.context.displayName) (\(Int(result.contextConfidence * 100))%)")
                    }
                }
            }
            .onChange(of: navigateToResult) { oldValue, newValue in
                logger.info("🔄 navigateToResult 변경: \(oldValue) → \(newValue)")
            }
            .onChange(of: analysisResult?.places.count) { oldValue, newValue in
                logger.info("🔄 analysisResult 변경: places \(oldValue ?? -1) → \(newValue ?? -1)")
            }
        }
        .onAppear {
            logger.info("📱 AnalyzingView 나타남 - 선택된 사진: \(viewModel.selectedAssets.count)장")
        }
    }

    // MARK: - Progress View
    private var progressView: some View {
        VStack(spacing: WanderSpacing.space6) {
            // Animated Icon
            ZStack {
                Circle()
                    .stroke(WanderColors.primaryPale, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: engine.progress)
                    .stroke(WanderColors.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: engine.progress)

                // 분석 단계에 따른 아이콘 변경
                analysisStepIcon
                    .font(.system(size: 40))
                    .foregroundColor(WanderColors.primary)
            }

            // Progress Text
            VStack(spacing: WanderSpacing.space2) {
                // 분석 레벨 배지
                if engine.currentAnalysisLevel >= .smart {
                    HStack(spacing: WanderSpacing.space1) {
                        Image(systemName: engine.currentAnalysisLevel == .advanced ? "brain" : "sparkles")
                            .font(.system(size: 12))
                        Text(engine.currentAnalysisLevel.displayName)
                            .font(WanderTypography.caption1)
                    }
                    .foregroundColor(WanderColors.primary)
                    .padding(.horizontal, WanderSpacing.space3)
                    .padding(.vertical, WanderSpacing.space1)
                    .background(WanderColors.primaryPale)
                    .cornerRadius(WanderSpacing.radiusSmall)
                }

                Text("analysis.analyzing".localized)
                    .font(WanderTypography.title2)
                    .foregroundColor(WanderColors.textPrimary)

                Text(engine.currentStep)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
                    .animation(.easeInOut, value: engine.currentStep)
                    .multilineTextAlignment(.center)

                Text("\(Int(engine.progress * 100))%")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.primary)
                    .padding(.top, WanderSpacing.space2)
            }

            // Photo Count
            Text("analysis.photoCount".localized(with: viewModel.selectedAssets.count))
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)

            // 분석 단계 인디케이터 (스마트 분석 시)
            if engine.currentAnalysisLevel >= .smart {
                smartAnalysisStepsIndicator
                    .padding(.top, WanderSpacing.space4)
            }
        }
    }

    // MARK: - Analysis Step Icon
    @ViewBuilder
    private var analysisStepIcon: some View {
        let step = engine.currentStep
        if step.contains("메타데이터") || step.contains("사진") {
            Image(systemName: "photo.stack")
        } else if step.contains("위치") || step.contains("GPS") {
            Image(systemName: "location")
        } else if step.contains("동선") || step.contains("클러스터") {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
        } else if step.contains("주소") || step.contains("geocoding") {
            Image(systemName: "map")
        } else if step.contains("장면") || step.contains("Vision") {
            Image(systemName: "eye")
        } else if step.contains("주변") || step.contains("POI") {
            Image(systemName: "mappin.and.ellipse")
        } else if step.contains("제목") {
            Image(systemName: "text.badge.star")
        } else if step.contains("AI") {
            Image(systemName: "brain")
        } else if step.contains("완료") {
            Image(systemName: "checkmark")
        } else {
            Image(systemName: "sparkles")
        }
    }

    // MARK: - Smart Analysis Steps Indicator
    private var smartAnalysisStepsIndicator: some View {
        HStack(spacing: WanderSpacing.space3) {
            ForEach(SmartAnalysisCoordinator.AnalysisStep.allCases, id: \.rawValue) { step in
                // iOS 18+ 전용 단계는 조건부 표시
                if step != .advancedAI || engine.currentAnalysisLevel >= .advanced {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 8, height: 8)

                        Text(step.emoji)
                            .font(.system(size: 10))
                    }
                }
            }
        }
    }

    private func stepColor(for step: SmartAnalysisCoordinator.AnalysisStep) -> Color {
        // 현재 진행 상황에 따른 색상
        let currentProgress = engine.progress

        // 각 단계의 예상 진행률 구간
        let stepRanges: [SmartAnalysisCoordinator.AnalysisStep: ClosedRange<Double>] = [
            .metadata: 0...0.10,
            .clustering: 0.10...0.20,
            .geocoding: 0.20...0.35,
            .vision: 0.45...0.65,
            .poi: 0.65...0.80,
            .titleGen: 0.80...0.90,
            .advancedAI: 0.90...0.95,
            .finalizing: 0.95...1.0
        ]

        guard let range = stepRanges[step] else {
            return WanderColors.surface
        }

        if currentProgress >= range.upperBound {
            return WanderColors.success  // 완료
        } else if currentProgress >= range.lowerBound {
            return WanderColors.primary  // 진행 중
        } else {
            return WanderColors.surface  // 대기
        }
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: WanderSpacing.space5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.warning)

            Text("analysis.failed".localized)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(message)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                dismiss()
            }) {
                Text("analysis.goBack".localized)
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

    // MARK: - Privacy Badge
    private var privacyBadge: some View {
        HStack(spacing: WanderSpacing.space2) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(WanderColors.success)

            Text("analysis.privacyNote".localized)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
        .padding(.horizontal, WanderSpacing.space4)
        .padding(.vertical, WanderSpacing.space3)
        .background(WanderColors.successBackground)
        .cornerRadius(WanderSpacing.radiusMedium)
    }

    // MARK: - Start Analysis
    private func startAnalysis() async {
        // 이미 분석이 시작되었으면 중복 실행 방지
        guard !hasStartedAnalysis else {
            logger.info("⚠️ 분석이 이미 진행 중이거나 완료됨 - 중복 실행 방지")
            return
        }
        hasStartedAnalysis = true

        logger.info("🚀 분석 시작 - 사진 \(viewModel.selectedAssets.count)장")

        // 사용자 장소 로드
        do {
            let descriptor = FetchDescriptor<UserPlace>(
                predicate: #Predicate { $0.latitude != 0 && $0.longitude != 0 }
            )
            let userPlaces = try modelContext.fetch(descriptor)
            engine.userPlaces = userPlaces
            logger.info("🏠 사용자 장소 \(userPlaces.count)개 로드됨")
        } catch {
            logger.warning("⚠️ 사용자 장소 로드 실패: \(error.localizedDescription)")
        }

        // v3.1: 학습된 장소 패턴 로드
        do {
            let learnedDescriptor = FetchDescriptor<LearnedPlace>(
                predicate: #Predicate { $0.isConfirmed && !$0.isIgnored }
            )
            let learnedPlaces = try modelContext.fetch(learnedDescriptor)
            engine.learnedPlaces = learnedPlaces
            logger.info("📊 학습된 장소 \(learnedPlaces.count)개 로드됨")
        } catch {
            logger.warning("⚠️ 학습된 장소 로드 실패: \(error.localizedDescription)")
        }

        // v3.2: ModelContext 전달 (LearnedPlace 자동 학습용)
        engine.modelContext = modelContext

        do {
            let result = try await engine.analyze(assets: viewModel.selectedAssets)

            logger.info("✅ 분석 완료!")
            logger.info("   - 제목: \(result.title)")
            logger.info("   - 장소 수: \(result.places.count)")
            logger.info("   - 사진 수: \(result.photoCount)")
            logger.info("   - 총 거리: \(result.totalDistance)km")

            logger.info("📲 결과 설정 중...")
            analysisResult = result
            logger.info("📲 analysisResult 설정 완료, navigateToResult = true 설정")
            navigateToResult = true
            logger.info("📲 navigateToResult 설정 완료: \(navigateToResult)")
        } catch {
            logger.error("❌ 분석 실패: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

// Make PhotoSelectionViewModel conform to ObservableObject for compatibility
extension PhotoSelectionViewModel: ObservableObject {}

#Preview {
    AnalyzingView(viewModel: PhotoSelectionViewModel())
}
