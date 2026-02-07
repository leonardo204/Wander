import SwiftUI

/// Wander Intelligence 섹션
/// NOTE: 연구 문서 Section 7.4에 따라 TravelDNA/TripScore/MomentScore는 제거됨 (근거 불명확)
/// 여행/혼합 컨텍스트에서만 스토리와 인사이트를 표시
struct WanderIntelligenceSection: View {
    let result: AnalysisResult
    var context: TravelContext = .travel

    var body: some View {
        VStack(spacing: WanderSpacing.space5) {
            // Insights Preview (여행/혼합에서만 표시)
            if !result.insights.isEmpty {
                InsightsPreview(insights: result.insights, summary: result.insightSummary)
            }

            // Story Preview (여행/혼합에서만 표시)
            if let story = result.travelStory {
                StoryPreviewCard(story: story, context: context)
            }
        }
    }
}

// MARK: - Insights Preview
struct InsightsPreview: View {
    let insights: [InsightEngine.TravelInsight]
    let summary: InsightEngine.InsightSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("발견된 인사이트")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                if let summary = summary {
                    Text("\(summary.totalCount)개 발견")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }
            }

            // Top 3 Insights
            ForEach(insights.prefix(3), id: \.id) { insight in
                InsightCard(insight: insight)
            }

            // Show More
            if insights.count > 3 {
                Button(action: {}) {
                    HStack {
                        Text("더 보기")
                        Image(systemName: "chevron.right")
                    }
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.primary)
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let insight: InsightEngine.TravelInsight

    var body: some View {
        HStack(spacing: WanderSpacing.space3) {
            // Emoji
            Text(insight.emoji)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(WanderColors.background)
                .cornerRadius(WanderSpacing.radiusMedium)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(WanderTypography.bodySmall)
                        .foregroundColor(WanderColors.textPrimary)

                    Spacer()

                    // Importance indicator
                    if insight.importance >= .highlight {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(WanderColors.warning)
                    }
                }

                Text(insight.description)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(WanderSpacing.space3)
        .background(WanderColors.background)
        .cornerRadius(WanderSpacing.radiusMedium)
    }
}

// MARK: - Story Preview Card
struct StoryPreviewCard: View {
    let story: StoryWeavingService.TravelStory
    var context: TravelContext = .travel

    private var storyTitle: String {
        switch context {
        case .daily, .outing: return "스토리"
        case .travel: return "여행 스토리"
        case .mixed: return "스토리"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text(storyTitle)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Text(story.mood.emoji)
                    Text(story.mood.koreanName)
                        .font(WanderTypography.caption1)
                }
                .foregroundColor(WanderColors.primary)
            }

            // Story Title
            Text(story.title)
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            // Tagline
            Text(story.tagline)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .italic()

            // Opening Preview
            Text(story.opening)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .lineLimit(3)

            // Keywords
            if !story.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WanderSpacing.space2) {
                        ForEach(story.keywords, id: \.self) { keyword in
                            Text("#\(keyword)")
                                .font(WanderTypography.caption2)
                                .foregroundColor(WanderColors.primary)
                                .padding(.horizontal, WanderSpacing.space2)
                                .padding(.vertical, 4)
                                .background(WanderColors.primaryPale)
                                .cornerRadius(WanderSpacing.radiusSmall)
                        }
                    }
                }
            }

            // Read Full Story Button
            NavigationLink(destination: AIStoryFullView(story: story, context: context)) {
                HStack {
                    Text("전체 스토리 보기")
                    Image(systemName: "chevron.right")
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.primary)
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }
}
