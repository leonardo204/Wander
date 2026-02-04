import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ShareFlowView")

// MARK: - 공유 플로우 단계

enum ShareFlowStep: Int, CaseIterable {
    case selectDestination = 0  // 공유 대상 선택
    case editPreview = 1        // 미리보기 + 편집
}

// MARK: - 공유 플로우 뷰

/// 공유 기능의 전체 플로우를 관리하는 컨테이너 뷰
struct ShareFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShareFlowViewModel

    init(record: TravelRecord) {
        _viewModel = StateObject(wrappedValue: ShareFlowViewModel(record: record))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WanderColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 단계 인디케이터
                    StepIndicator(currentStep: viewModel.currentStep)
                        .padding(.horizontal, WanderSpacing.screenMargin)
                        .padding(.top, WanderSpacing.space2)

                    // 콘텐츠
                    switch viewModel.currentStep {
                    case .selectDestination:
                        ShareOptionsView(
                            selectedDestination: $viewModel.configuration.destination,
                            isInstagramInstalled: viewModel.isInstagramInstalled,
                            onNext: { viewModel.goToNextStep() }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))

                    case .editPreview:
                        SharePreviewEditorView(
                            viewModel: viewModel,
                            onShare: { await viewModel.share() },
                            onBack: { viewModel.goToPreviousStep() }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                    }
                }

                // 로딩 오버레이
                if viewModel.isLoading {
                    LoadingOverlay(message: "이미지 생성 중...")
                }

                // Instagram 안내 오버레이
                if viewModel.showInstagramGuidance {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.showInstagramGuidance = false
                        }

                    InstagramShareGuidanceView(
                        isPresented: $viewModel.showInstagramGuidance
                    ) {
                        Task {
                            await viewModel.continueInstagramShare()
                        }
                    }
                    .padding(WanderSpacing.screenMargin)
                }

                // Instagram 미설치 알럿
                if viewModel.showInstagramNotInstalledAlert {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.showInstagramNotInstalledAlert = false
                        }

                    InstagramNotInstalledAlert(
                        isPresented: $viewModel.showInstagramNotInstalledAlert
                    ) {
                        Task {
                            await viewModel.openAppStore()
                        }
                    }
                    .padding(WanderSpacing.screenMargin)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(WanderColors.textSecondary)
                }

                ToolbarItem(placement: .principal) {
                    Text("공유하기")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)
                }
            }
            .alert("오류", isPresented: $viewModel.showError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
            .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadPhotos()
        }
    }
}

// MARK: - 단계 인디케이터

private struct StepIndicator: View {
    let currentStep: ShareFlowStep

    var body: some View {
        HStack(spacing: WanderSpacing.space2) {
            ForEach(ShareFlowStep.allCases, id: \.rawValue) { step in
                Rectangle()
                    .fill(step.rawValue <= currentStep.rawValue ? WanderColors.primary : WanderColors.border)
                    .frame(height: 3)
                    .cornerRadius(1.5)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentStep)
    }
}

// MARK: - 로딩 오버레이

private struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: WanderSpacing.space4) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(WanderTypography.body)
                    .foregroundColor(.white)
            }
            .padding(WanderSpacing.space6)
            .background(.ultraThinMaterial)
            .cornerRadius(WanderSpacing.radiusLarge)
        }
    }
}

// MARK: - ShareFlowViewModel

@MainActor
final class ShareFlowViewModel: ObservableObject {
    // MARK: - Properties

    let record: TravelRecord
    private let shareService = ShareService.shared

    @Published var currentStep: ShareFlowStep = .selectDestination
    @Published var configuration = ShareConfiguration()
    @Published var loadedPhotos: [SharePhotoItem] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var shouldDismiss = false

    // Instagram
    @Published var showInstagramGuidance = false
    @Published var showInstagramNotInstalledAlert = false
    private var pendingInstagramImage: UIImage?
    private var pendingInstagramCaption: String = ""

    var isInstagramInstalled: Bool {
        shareService.isInstagramInstalled
    }

    // MARK: - Computed Properties

    var selectedPhotos: [UIImage] {
        loadedPhotos
            .filter { $0.isSelected }
            .sorted { $0.order < $1.order }
            .compactMap { $0.image }
    }

    var selectedPhotoCount: Int {
        loadedPhotos.filter { $0.isSelected }.count
    }

    // MARK: - Init

    init(record: TravelRecord) {
        self.record = record
        setupDefaultConfiguration()
    }

    private func setupDefaultConfiguration() {
        // 기본 캡션 설정 (AI 스토리가 있으면 사용)
        if let story = record.aiStory {
            configuration.caption = story
        } else {
            configuration.caption = "\(record.title)\n\(record.shareDateRange)"
        }

        // 기본 해시태그 설정
        var hashtags: [String] = []

        // 지역 기반 해시태그
        let addresses = record.days.flatMap { $0.places.map { $0.address } }
        hashtags.append(contentsOf: HashtagRecommendation.locationHashtags(from: addresses))

        // 시즌 기반 해시태그
        hashtags.append(contentsOf: HashtagRecommendation.seasonHashtags(from: record.startDate))

        // 일반 해시태그
        hashtags.append(contentsOf: HashtagRecommendation.generalHashtags.prefix(3))

        configuration.hashtags = Array(Set(hashtags)).prefix(10).map { $0 }
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard currentStep.rawValue < ShareFlowStep.allCases.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = ShareFlowStep(rawValue: currentStep.rawValue + 1) ?? currentStep
        }
    }

    func goToPreviousStep() {
        guard currentStep.rawValue > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = ShareFlowStep(rawValue: currentStep.rawValue - 1) ?? currentStep
        }
    }

    // MARK: - Photo Loading

    func loadPhotos() async {
        logger.info("📤 [ShareFlowViewModel] 사진 로드 시작")
        isLoading = true

        let assetIdentifiers = record.sharePhotoAssetIdentifiers
        let images = await shareService.loadImages(from: assetIdentifiers)

        // SharePhotoItem으로 변환
        loadedPhotos = zip(assetIdentifiers, images).enumerated().map { index, pair in
            SharePhotoItem(
                assetIdentifier: pair.0,
                image: pair.1,
                isSelected: index < 5,  // 처음 5장만 선택
                order: index
            )
        }

        isLoading = false
        logger.info("📤 [ShareFlowViewModel] 사진 로드 완료 - \(self.loadedPhotos.count)개")
    }

    // MARK: - Sharing

    func share() async {
        guard !selectedPhotos.isEmpty else {
            showError(ShareError.noPhotosSelected)
            return
        }

        isLoading = true

        do {
            switch configuration.destination {
            case .general:
                await shareGeneral()

            case .instagramFeed:
                try await shareToInstagramFeed()

            case .instagramStory:
                try await shareToInstagramStory()
            }
        } catch let error as ShareError {
            handleShareError(error)
        } catch {
            showError(ShareError.unknown(error))
        }

        isLoading = false
    }

    private func shareGeneral() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        do {
            try await shareService.shareGeneral(
                photos: selectedPhotos,
                data: record,
                configuration: configuration,
                from: rootVC
            )
            shouldDismiss = true
        } catch {
            showError(ShareError.unknown(error))
        }
    }

    private func shareToInstagramFeed() async throws {
        guard shareService.isInstagramInstalled else {
            showInstagramNotInstalledAlert = true
            return
        }

        // 이미지 생성
        var feedConfig = configuration
        feedConfig.destination = .instagramFeed

        let image = try await ShareImageGenerator.shared.generateImage(
            photos: selectedPhotos,
            data: record,
            configuration: feedConfig
        )

        // 안내 화면 표시 전 준비
        pendingInstagramImage = image
        pendingInstagramCaption = configuration.clipboardText
        showInstagramGuidance = true
    }

    private func shareToInstagramStory() async throws {
        guard shareService.isInstagramInstalled else {
            showInstagramNotInstalledAlert = true
            return
        }

        try await shareService.shareToInstagramStories(
            photos: selectedPhotos,
            data: record,
            configuration: configuration
        )
        shouldDismiss = true
    }

    func continueInstagramShare() async {
        showInstagramGuidance = false

        guard let image = pendingInstagramImage else { return }

        do {
            try await InstagramShareService.shared.shareToFeed(
                image: image,
                caption: pendingInstagramCaption
            )
            shouldDismiss = true
        } catch {
            showError(ShareError.unknown(error))
        }
    }

    func openAppStore() async {
        await shareService.openInstagramAppStore()
    }

    // MARK: - Error Handling

    private func handleShareError(_ error: ShareError) {
        switch error {
        case .instagramNotInstalled:
            showInstagramNotInstalledAlert = true
        default:
            showError(error)
        }
    }

    private func showError(_ error: ShareError) {
        errorMessage = error.errorDescription
        showError = true
    }
}

// MARK: - Preview

#Preview {
    // Preview용 더미 데이터 (실제 앱에서는 TravelRecord 전달)
    Text("ShareFlowView Preview")
}
