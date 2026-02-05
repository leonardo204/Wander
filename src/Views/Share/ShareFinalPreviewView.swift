import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ShareFinalPreviewView")

// MARK: - 최종 미리보기 뷰 (Step 3)

/// 실제 공유 이미지를 생성하여 미리보기하고 공유하는 뷰
struct ShareFinalPreviewView: View {
    @ObservedObject var viewModel: ShareFlowViewModel
    let onShare: () async -> Void
    let onBack: () -> Void

    @State private var previewImages: [UIImage] = []
    @State private var currentImageIndex: Int = 0
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var showFullScreenImage = false

    var body: some View {
        VStack(spacing: 0) {
            // 미리보기 영역
            ScrollView {
                VStack(spacing: WanderSpacing.space4) {
                    // 헤더
                    headerSection

                    // 이미지 미리보기 (페이지네이션)
                    imagePreviewSection

                    // 공유 정보 요약
                    shareInfoSection
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }

            // 하단 버튼
            bottomButtons
        }
        .task {
            await generatePreviewImages()
        }
        .onChange(of: previewImages.count) { oldValue, newValue in
            logger.info("📤 [ShareFinalPreviewView] previewImages.count 변경: \(oldValue) -> \(newValue)")
        }
        .onChange(of: isGenerating) { oldValue, newValue in
            logger.info("📤 [ShareFinalPreviewView] isGenerating 변경: \(oldValue) -> \(newValue)")
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            ZoomableImageViewer(
                images: previewImages,
                currentIndex: $currentImageIndex,
                isPresented: $showFullScreenImage
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: WanderSpacing.space2) {
            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 40))
                .foregroundColor(WanderColors.primary)

            Text("최종 미리보기")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            if previewImages.count > 1 {
                Text("\(previewImages.count)장의 이미지가 공유됩니다")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            } else {
                Text("아래 이미지가 공유됩니다")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, WanderSpacing.space2)
    }

    // MARK: - Image Preview Section

    private var imagePreviewSection: some View {
        VStack(spacing: WanderSpacing.space3) {
            ZStack {
                if !previewImages.isEmpty {
                    // 여러 장 이미지: TabView로 스와이프
                    TabView(selection: $currentImageIndex) {
                        ForEach(previewImages.indices, id: \.self) { index in
                            Image(uiImage: previewImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(WanderSpacing.radiusLarge)
                                .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                                .padding(.horizontal, 4)
                                .tag(index)
                                .onTapGesture {
                                    showFullScreenImage = true
                                }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 420) // 명시적 높이 설정
                    .onAppear {
                        logger.info("📤 [ShareFinalPreviewView] TabView 표시됨 - \(previewImages.count)장")
                    }

                } else if isGenerating {
                    // 생성 중
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .fill(WanderColors.primaryPale)
                        .aspectRatio(viewModel.configuration.destination.aspectRatio, contentMode: .fit)
                        .frame(height: 420)
                        .overlay(
                            VStack(spacing: WanderSpacing.space3) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(WanderColors.primary)
                                Text("이미지 생성 중...")
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textSecondary)
                            }
                        )
                } else if let error = generationError {
                    // 에러
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .fill(WanderColors.primaryPale)
                        .aspectRatio(viewModel.configuration.destination.aspectRatio, contentMode: .fit)
                        .frame(height: 420)
                        .overlay(
                            VStack(spacing: WanderSpacing.space3) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(WanderColors.error)
                                Text(error)
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textSecondary)
                                    .multilineTextAlignment(.center)

                                Button("다시 시도") {
                                    Task { await generatePreviewImages() }
                                }
                                .font(WanderTypography.headline)
                                .foregroundColor(WanderColors.primary)
                            }
                            .padding()
                        )
                } else {
                    // 초기 상태 (아무것도 없을 때)
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .fill(WanderColors.primaryPale)
                        .frame(height: 420)
                }
            }
            .frame(height: 420)
            // 페이지네이션 제거 - 스와이프로만 이동

            // 이미지 크기 정보 + 확대 힌트
            if !previewImages.isEmpty {
                VStack(spacing: WanderSpacing.space2) {
                    // 확대 힌트
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                        Text("이미지를 탭하면 확대할 수 있습니다")
                    }
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.primary)

                    // 이미지 정보
                    HStack(spacing: WanderSpacing.space4) {
                        Label(viewModel.configuration.templateStyle.displayName, systemImage: "paintbrush")
                        Label("\(Int(viewModel.configuration.destination.imageSize.width))×\(Int(viewModel.configuration.destination.imageSize.height))", systemImage: "aspectratio")
                        if previewImages.count > 1 {
                            Label("\(previewImages.count)장", systemImage: "photo.on.rectangle")
                        }
                    }
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Share Info Section

    private var shareInfoSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // 공유 대상
            HStack {
                Image(systemName: viewModel.configuration.destination.icon)
                    .foregroundColor(WanderColors.primary)
                Text(viewModel.configuration.destination.displayName)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)
            }

            Divider()

            // 선택된 사진 수
            HStack {
                Text("선택된 사진")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
                Spacer()
                Text("\(viewModel.selectedPhotoCount)장")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)
            }

            // 생성된 이미지 수
            if previewImages.count > 0 {
                HStack {
                    Text("생성된 이미지")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                    Spacer()
                    Text("\(previewImages.count)장")
                        .font(WanderTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(WanderColors.primary)
                }
            }

            // 캡션 미리보기
            if !viewModel.configuration.caption.isEmpty {
                VStack(alignment: .leading, spacing: WanderSpacing.space1) {
                    Text("캡션")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                    Text(viewModel.configuration.caption)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textPrimary)
                        .lineLimit(3)
                }
            }

            // 해시태그
            if !viewModel.configuration.hashtags.isEmpty {
                VStack(alignment: .leading, spacing: WanderSpacing.space1) {
                    Text("해시태그")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                    Text(viewModel.configuration.hashtags.map { "#\($0)" }.joined(separator: " "))
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.primary)
                        .lineLimit(2)
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Divider()
                .foregroundColor(WanderColors.border)

            HStack(spacing: WanderSpacing.space3) {
                // 이전 버튼 (편집 화면으로)
                Button(action: onBack) {
                    HStack(spacing: WanderSpacing.space2) {
                        Image(systemName: "arrow.left")
                        Text("수정하기")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.surface)
                    .cornerRadius(WanderSpacing.radiusLarge)
                    .overlay(
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                            .strokeBorder(WanderColors.border, lineWidth: 1)
                    )
                }

                // 공유 버튼
                Button {
                    Task { await onShare() }
                } label: {
                    HStack(spacing: WanderSpacing.space2) {
                        Image(systemName: viewModel.configuration.destination.icon)
                        Text(previewImages.count > 1 ? "공유하기 (\(previewImages.count)장)" : "공유하기")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(
                        !previewImages.isEmpty
                            ? WanderColors.primary
                            : WanderColors.textTertiary
                    )
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(previewImages.isEmpty)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space4)
        }
        .background(WanderColors.surface)
    }

    // MARK: - Preview Image Generation

    private func generatePreviewImages() async {
        logger.info("📤 [ShareFinalPreviewView] 이미지 생성 시작")

        guard viewModel.selectedPhotoCount > 0 else {
            await MainActor.run {
                generationError = "선택된 사진이 없습니다"
            }
            return
        }

        logger.info("📤 [ShareFinalPreviewView] 선택된 사진: \(viewModel.selectedPhotos.count)장")

        await MainActor.run {
            isGenerating = true
            generationError = nil
            previewImages = []
            currentImageIndex = 0
        }

        do {
            let images = try await ShareImageGenerator.shared.generateImages(
                photos: viewModel.selectedPhotos,
                data: viewModel.record,
                configuration: viewModel.configuration
            )

            logger.info("📤 [ShareFinalPreviewView] 이미지 생성 완료: \(images.count)장")

            // 각 이미지 크기 확인 (가볍게)
            for (index, image) in images.enumerated() {
                logger.info("📤 [ShareFinalPreviewView] 이미지[\(index)]: \(Int(image.size.width))x\(Int(image.size.height))")
            }

            // MainActor에서 상태 업데이트
            await MainActor.run {
                self.previewImages = images
                self.isGenerating = false
                logger.info("📤 [ShareFinalPreviewView] 상태 업데이트 완료 - previewImages: \(self.previewImages.count)장")
            }

        } catch {
            logger.error("📤 [ShareFinalPreviewView] 이미지 생성 실패: \(error.localizedDescription)")
            await MainActor.run {
                generationError = "이미지 생성에 실패했습니다"
                isGenerating = false
            }
        }
    }
}

// MARK: - Zoomable Image Viewer

/// 핀치 투 줌을 지원하는 전체화면 이미지 뷰어
struct ZoomableImageViewer: View {
    let images: [UIImage]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // 배경
            Color.black.ignoresSafeArea()

            // 이미지
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableImageContent(
                        image: images[index],
                        scale: index == currentIndex ? $scale : .constant(1.0),
                        lastScale: index == currentIndex ? $lastScale : .constant(1.0),
                        offset: index == currentIndex ? $offset : .constant(.zero),
                        lastOffset: index == currentIndex ? $lastOffset : .constant(.zero)
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 상단 컨트롤
            VStack {
                HStack {
                    Spacer()

                    // 닫기 버튼
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }

                Spacer()

                // 페이지 인디케이터
                if images.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: index == currentIndex ? 10 : 8)
                        }
                    }
                    .padding(.bottom, 40)
                }

                // 줌 힌트
                Text("두 손가락으로 확대/축소")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
        }
        .onChange(of: currentIndex) { _, _ in
            // 페이지 변경 시 줌 리셋
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}

/// 줌 가능한 이미지 콘텐츠
struct ZoomableImageContent: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 1), 5)  // 1x ~ 5x 줌
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        if scale < 1.2 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1 {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                        if scale <= 1 {
                            withAnimation(.spring()) {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
            )
    }
}

// MARK: - Preview

#Preview {
    Text("ShareFinalPreviewView Preview")
}
