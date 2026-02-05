import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ShareEditOptionsView")

// MARK: - 공유 편집 옵션 뷰 (Step 2)

/// 템플릿 선택, 사진 선택, 캡션/해시태그 편집 뷰
/// 실제 이미지 생성은 다음 단계(ShareFinalPreviewView)에서 수행
struct ShareEditOptionsView: View {
    @ObservedObject var viewModel: ShareFlowViewModel
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: WanderSpacing.space5) {
                    // 템플릿 선택 (기본 미리보기)
                    templatePickerSection

                    // 사진 선택
                    photoSelectionSection

                    // 감성 키워드 편집 (이미지 내 표시)
                    impressionSection

                    // 캡션 편집 (클립보드용)
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
    }

    // MARK: - Template Picker Section (기본 템플릿 미리보기)

    private var templatePickerSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Text("스타일 선택")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            // 템플릿 카드 (기본 미리보기)
            HStack(spacing: WanderSpacing.space3) {
                ForEach(ShareTemplateStyle.allCases) { style in
                    TemplatePreviewCard(
                        style: style,
                        isSelected: viewModel.configuration.templateStyle == style
                    ) {
                        viewModel.configuration.templateStyle = style
                    }
                }
            }

            // 선택된 템플릿 설명
            Text(selectedTemplateDescription)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
                .padding(.top, WanderSpacing.space1)
        }
    }

    private var selectedTemplateDescription: String {
        switch viewModel.configuration.templateStyle {
        case .modernGlass:
            return "사진 위에 글래스 효과의 정보 패널이 표시됩니다"
        case .polaroidGrid:
            return "폴라로이드 스타일로 최대 3장의 사진이 배치됩니다"
        case .cleanMinimal:
            return "깔끔한 흰색 배경에 사진과 정보가 표시됩니다"
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
                    .foregroundColor(viewModel.selectedPhotoCount > 0 ? WanderColors.primary : WanderColors.textSecondary)
            }

            if viewModel.loadedPhotos.isEmpty {
                // 로딩 중
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(WanderColors.primary)
                    Text("사진 로드 중...")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                    Spacer()
                }
                .frame(height: 80)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WanderSpacing.space2) {
                        ForEach(viewModel.loadedPhotos.indices, id: \.self) { index in
                            PhotoSelectionThumbnail(
                                photo: viewModel.loadedPhotos[index],
                                onTap: {
                                    viewModel.loadedPhotos[index].isSelected.toggle()
                                }
                            )
                        }
                    }
                }

                // 안내 텍스트
                VStack(alignment: .leading, spacing: WanderSpacing.space1) {
                    if viewModel.configuration.templateStyle == .polaroidGrid {
                        Text("폴라로이드 스타일은 최대 3장까지 표시됩니다")
                            .font(WanderTypography.caption2)
                            .foregroundColor(WanderColors.textTertiary)
                    }
                    Text("첫 번째 선택 사진이 메인으로 사용됩니다")
                        .font(WanderTypography.caption2)
                        .foregroundColor(WanderColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Impression Section (감성 키워드)

    private var impressionSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("감성 키워드")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                // Vision 분석 키워드가 있으면 배지 표시
                if viewModel.record.hasKeywords {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                        Text("AI 분석")
                            .font(WanderTypography.caption1)
                    }
                    .foregroundColor(WanderColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WanderColors.primaryPale)
                    .cornerRadius(WanderSpacing.radiusSmall)
                }
            }

            TextField("로맨틱 · 힐링 · 도심탈출", text: $viewModel.configuration.impression)
                .font(WanderTypography.body)
                .padding(WanderSpacing.space3)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                        .strokeBorder(WanderColors.border, lineWidth: 1)
                )

            Text("이미지에 표시됩니다. 구분자(·)로 키워드를 구분하세요.")
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textTertiary)
        }
    }

    // MARK: - Caption Section (클립보드용)

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

            Text("SNS 공유 시 클립보드에 복사됩니다 (이미지에 표시되지 않음)")
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textTertiary)
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
                // 이전 버튼
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

                // 다음 버튼 (미리보기로 이동)
                Button(action: onNext) {
                    HStack(spacing: WanderSpacing.space2) {
                        Text("미리보기")
                        Image(systemName: "arrow.right")
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
}

// MARK: - Template Preview Card (기본 템플릿 미리보기)

private struct TemplatePreviewCard: View {
    let style: ShareTemplateStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: WanderSpacing.space2) {
                // 템플릿 미리보기 (기본 형태)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? WanderColors.primaryPale : WanderColors.surface)
                        .frame(width: 90, height: 112)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isSelected ? WanderColors.primary : WanderColors.border,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )

                    // 템플릿 형태 시각화
                    templateVisualization
                }

                Text(style.displayName)
                    .font(WanderTypography.caption1)
                    .foregroundColor(isSelected ? WanderColors.primary : WanderColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var templateVisualization: some View {
        switch style {
        case .modernGlass:
            // 사진 배경 + 하단 글래스 패널
            VStack(spacing: 0) {
                // 사진 영역
                RoundedRectangle(cornerRadius: 4)
                    .fill(WanderColors.border.opacity(0.5))
                    .frame(width: 70, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(WanderColors.textTertiary)
                    )

                Spacer().frame(height: 8)

                // 글래스 패널
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 70, height: 28)
                    .overlay(
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(WanderColors.textTertiary)
                                .frame(width: 40, height: 4)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(WanderColors.textTertiary.opacity(0.5))
                                .frame(width: 30, height: 3)
                        }
                    )
            }
            .padding(6)

        case .polaroidGrid:
            // 3개의 작은 폴라로이드
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(WanderColors.border.opacity(0.5))
                            .frame(width: 18, height: 16)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(WanderColors.textTertiary.opacity(0.3))
                            .frame(width: 18, height: 4)
                    }
                    .padding(2)
                    .background(Color.white)
                    .cornerRadius(2)
                    .rotationEffect(.degrees(Double([-3, 2, -1][index])))
                }
            }
            .padding(.top, 20)

        case .cleanMinimal:
            // 중앙 사진 + 하단 텍스트
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(WanderColors.border.opacity(0.5))
                    .frame(width: 60, height: 50)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundColor(WanderColors.textTertiary)
                    )

                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(WanderColors.textTertiary)
                        .frame(width: 40, height: 4)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(WanderColors.textTertiary.opacity(0.5))
                        .frame(width: 30, height: 3)
                }
            }
            .padding(6)
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
    Text("ShareEditOptionsView Preview")
}
