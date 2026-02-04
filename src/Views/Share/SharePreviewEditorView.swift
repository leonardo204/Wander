import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "SharePreviewEditorView")

// MARK: - 공유 미리보기 + 편집 뷰

/// 공유 이미지 미리보기 및 편집(템플릿, 사진, 캡션, 해시태그) 뷰
struct SharePreviewEditorView: View {
    @ObservedObject var viewModel: ShareFlowViewModel
    let onShare: () async -> Void
    let onBack: () -> Void

    @State private var previewImage: UIImage?
    @State private var isGeneratingPreview = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: WanderSpacing.space5) {
                    // 미리보기 이미지
                    previewSection

                    // 템플릿 선택
                    templatePickerSection

                    // 사진 선택/순서
                    photoSelectionSection

                    // 캡션 편집
                    captionSection

                    // 해시태그 편집
                    hashtagSection
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }

            // 하단 버튼
            bottomButtons
        }
        .onChange(of: viewModel.configuration.templateStyle) { _, _ in
            Task { await generatePreview() }
        }
        .onChange(of: viewModel.loadedPhotos) { _, _ in
            Task { await generatePreview() }
        }
        .task {
            await generatePreview()
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Text("미리보기")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            ZStack {
                if let image = previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(WanderSpacing.radiusLarge)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .fill(WanderColors.primaryPale)
                        .aspectRatio(viewModel.configuration.destination.aspectRatio, contentMode: .fit)
                        .overlay(
                            VStack(spacing: WanderSpacing.space3) {
                                if isGeneratingPreview {
                                    ProgressView()
                                        .tint(WanderColors.primary)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(WanderColors.primary)
                                }
                                Text(isGeneratingPreview ? "생성 중..." : "사진을 선택하세요")
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textSecondary)
                            }
                        )
                }
            }
            .frame(maxHeight: 400)
        }
    }

    // MARK: - Template Picker Section

    private var templatePickerSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Text("스타일")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            HStack(spacing: WanderSpacing.space3) {
                ForEach(ShareTemplateStyle.allCases) { style in
                    TemplateStyleButton(
                        style: style,
                        isSelected: viewModel.configuration.templateStyle == style
                    ) {
                        viewModel.configuration.templateStyle = style
                    }
                }
            }
        }
    }

    // MARK: - Photo Selection Section

    private var photoSelectionSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("사진 선택")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                Text("\(viewModel.selectedPhotoCount)장 선택")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WanderSpacing.space2) {
                    ForEach(viewModel.loadedPhotos.indices, id: \.self) { index in
                        PhotoSelectionThumbnail(
                            photo: viewModel.loadedPhotos[index],
                            onTap: {
                                viewModel.loadedPhotos[index].isSelected.toggle()
                                Task { await generatePreview() }
                            }
                        )
                    }
                }
            }

            Text("첫 번째 선택 사진이 메인으로 사용됩니다")
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textTertiary)
        }
    }

    // MARK: - Caption Section

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("캡션")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                Text("\(viewModel.configuration.caption.count)/2,200")
                    .font(WanderTypography.caption1)
                    .foregroundColor(
                        viewModel.configuration.caption.count > 2200
                            ? WanderColors.error
                            : WanderColors.textTertiary
                    )
            }

            TextEditor(text: $viewModel.configuration.caption)
                .font(WanderTypography.body)
                .frame(minHeight: 100)
                .padding(WanderSpacing.space3)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                        .strokeBorder(WanderColors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Hashtag Section

    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("해시태그")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                Text("\(viewModel.configuration.hashtags.count)개")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)
            }

            // 선택된 해시태그
            FlowLayout(spacing: WanderSpacing.space2) {
                ForEach(viewModel.configuration.hashtags, id: \.self) { tag in
                    HashtagChip(tag: tag, isRemovable: true) {
                        viewModel.configuration.hashtags.removeAll { $0 == tag }
                    }
                }

                // 추가 버튼
                AddHashtagButton {
                    // TODO: 해시태그 추가 시트 표시
                }
            }

            // 추천 해시태그
            VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                Text("추천")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)

                FlowLayout(spacing: WanderSpacing.space2) {
                    ForEach(suggestedHashtags, id: \.self) { tag in
                        HashtagChip(tag: tag, isRemovable: false) {
                            if !viewModel.configuration.hashtags.contains(tag) {
                                viewModel.configuration.hashtags.append(tag)
                            }
                        }
                    }
                }
            }
        }
    }

    private var suggestedHashtags: [String] {
        HashtagRecommendation.generalHashtags
            .filter { !viewModel.configuration.hashtags.contains($0) }
            .prefix(6)
            .map { $0 }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Divider()
                .foregroundColor(WanderColors.border)

            HStack(spacing: WanderSpacing.space3) {
                // 뒤로 버튼
                Button(action: onBack) {
                    Text("이전")
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
                        Text("공유하기")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(
                        viewModel.selectedPhotoCount > 0
                            ? WanderColors.primary
                            : WanderColors.textTertiary
                    )
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(viewModel.selectedPhotoCount == 0)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space4)
        }
        .background(WanderColors.surface)
    }

    // MARK: - Preview Generation

    private func generatePreview() async {
        guard viewModel.selectedPhotoCount > 0 else {
            previewImage = nil
            return
        }

        isGeneratingPreview = true

        do {
            let image = try await ShareImageGenerator.shared.generateImage(
                photos: viewModel.selectedPhotos,
                data: viewModel.record,
                configuration: viewModel.configuration
            )
            previewImage = image
        } catch {
            logger.error("📤 [SharePreviewEditorView] 미리보기 생성 실패: \(error.localizedDescription)")
        }

        isGeneratingPreview = false
    }
}

// MARK: - Template Style Button

private struct TemplateStyleButton: View {
    let style: ShareTemplateStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: WanderSpacing.space2) {
                // 미니 프리뷰 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? WanderColors.primary : WanderColors.primaryPale)
                        .frame(width: 60, height: 75)

                    Image(systemName: styleIcon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : WanderColors.primary)
                }

                Text(style.displayName)
                    .font(WanderTypography.caption1)
                    .foregroundColor(isSelected ? WanderColors.primary : WanderColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var styleIcon: String {
        switch style {
        case .modernGlass:
            return "sparkles.rectangle.stack"
        case .polaroidGrid:
            return "rectangle.split.3x1"
        case .cleanMinimal:
            return "rectangle"
        }
    }
}

// MARK: - Photo Selection Thumbnail

private struct PhotoSelectionThumbnail: View {
    let photo: SharePhotoItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipped()
                        .cornerRadius(WanderSpacing.radiusSmall)
                } else {
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusSmall)
                        .fill(WanderColors.primaryPale)
                        .frame(width: 72, height: 72)
                }

                // 선택 표시
                if photo.isSelected {
                    Circle()
                        .fill(WanderColors.primary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 4, y: -4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusSmall)
                    .strokeBorder(
                        photo.isSelected ? WanderColors.primary : Color.clear,
                        lineWidth: 3
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hashtag Chip

private struct HashtagChip: View {
    let tag: String
    let isRemovable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("#\(tag)")
                    .font(WanderTypography.caption1)

                if isRemovable {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundColor(isRemovable ? WanderColors.primary : WanderColors.textSecondary)
            .padding(.horizontal, WanderSpacing.space3)
            .padding(.vertical, WanderSpacing.space2)
            .background(isRemovable ? WanderColors.primaryPale : WanderColors.surface)
            .cornerRadius(WanderSpacing.radiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusSmall)
                    .strokeBorder(isRemovable ? WanderColors.primary.opacity(0.3) : WanderColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Hashtag Button

private struct AddHashtagButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("추가")
                    .font(WanderTypography.caption1)
            }
            .foregroundColor(WanderColors.textSecondary)
            .padding(.horizontal, WanderSpacing.space3)
            .padding(.vertical, WanderSpacing.space2)
            .background(WanderColors.surface)
            .cornerRadius(WanderSpacing.radiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusSmall)
                    .strokeBorder(WanderColors.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    Text("SharePreviewEditorView Preview")
}
