import SwiftUI

struct AnalyzingView: View {
    @ObservedObject var viewModel: PhotoSelectionViewModel
    @StateObject private var engine = AnalysisEngine()
    @State private var showResult = false
    @State private var analysisResult: AnalysisResult?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space8) {
                Spacer()

                if let error = errorMessage {
                    errorView(message: error)
                } else {
                    progressView
                }

                Spacer()

                privacyBadge
            }
            .padding(WanderSpacing.screenMargin)
            .background(WanderColors.background)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(WanderColors.textSecondary)
                }
            }
            .task {
                await startAnalysis()
            }
            .fullScreenCover(isPresented: $showResult) {
                if let result = analysisResult {
                    ResultView(result: result, selectedAssets: viewModel.selectedAssets)
                }
            }
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

                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(WanderColors.primary)
            }

            // Progress Text
            VStack(spacing: WanderSpacing.space2) {
                Text("분석 중...")
                    .font(WanderTypography.title2)
                    .foregroundColor(WanderColors.textPrimary)

                Text(engine.currentStep)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
                    .animation(.easeInOut, value: engine.currentStep)

                Text("\(Int(engine.progress * 100))%")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.primary)
                    .padding(.top, WanderSpacing.space2)
            }

            // Photo Count
            Text("\(viewModel.selectedAssets.count)장의 사진 분석 중")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)
        }
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: WanderSpacing.space5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.warning)

            Text("분석 실패")
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(message)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                dismiss()
            }) {
                Text("돌아가기")
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

            Text("모든 처리는 기기 내에서 이루어집니다")
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
        do {
            let result = try await engine.analyze(assets: viewModel.selectedAssets)
            analysisResult = result
            showResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Make PhotoSelectionViewModel conform to ObservableObject for compatibility
extension PhotoSelectionViewModel: ObservableObject {}

#Preview {
    AnalyzingView(viewModel: PhotoSelectionViewModel())
}
