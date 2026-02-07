import SwiftUI

// MARK: - AI Story Full View
struct AIStoryFullView: View {
    let story: StoryWeavingService.TravelStory
    var context: TravelContext = .travel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WanderSpacing.space5) {
                // Header
                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    HStack {
                        Text(story.mood.emoji)
                        Text(story.mood.koreanName)
                            .font(WanderTypography.caption1)
                    }
                    .foregroundColor(WanderColors.primary)

                    Text(story.title)
                        .font(WanderTypography.title1)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(story.tagline)
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                        .italic()
                }

                Divider()

                // Opening
                Text(story.opening)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)
                    .lineSpacing(6)

                // Chapters
                ForEach(story.chapters.indices, id: \.self) { index in
                    chapterView(story.chapters[index], number: index + 1)
                }

                // Climax
                if !story.climax.isEmpty {
                    VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                        Text("✨ 하이라이트")
                            .font(WanderTypography.headline)
                            .foregroundColor(WanderColors.primary)

                        Text(story.climax)
                            .font(WanderTypography.body)
                            .foregroundColor(WanderColors.textPrimary)
                            .lineSpacing(6)
                    }
                    .padding(WanderSpacing.space4)
                    .background(WanderColors.primaryPale)
                    .cornerRadius(WanderSpacing.radiusMedium)
                }

                // Closing
                Text(story.closing)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)
                    .lineSpacing(6)

                // Keywords
                if !story.keywords.isEmpty {
                    Divider()

                    FlowLayout(spacing: WanderSpacing.space2) {
                        ForEach(story.keywords, id: \.self) { keyword in
                            Text("#\(keyword)")
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.primary)
                                .padding(.horizontal, WanderSpacing.space3)
                                .padding(.vertical, WanderSpacing.space2)
                                .background(WanderColors.primaryPale)
                                .cornerRadius(WanderSpacing.radiusMedium)
                        }
                    }
                }
            }
            .padding(WanderSpacing.screenMargin)
        }
        .background(WanderColors.background)
        .navigationTitle(context == .travel ? "여행 스토리" : "스토리")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chapterView(_ chapter: StoryWeavingService.StoryChapter, number: Int) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("Chapter \(number)")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)

                Spacer()

                Text(chapter.placeName)
                    .font(WanderTypography.caption2)
                    .foregroundColor(WanderColors.textTertiary)
            }

            Text(chapter.title)
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            Text(chapter.content)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .lineSpacing(4)
        }
        .padding(.vertical, WanderSpacing.space2)
    }
}

// MARK: - Flow Layout (for Keywords)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
