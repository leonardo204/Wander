import SwiftUI

struct WanderIntelligenceSection: View {
    let result: AnalysisResult

    var body: some View {
        VStack(spacing: WanderSpacing.space5) {
            // Trip Score Card
            if let tripScore = result.tripScore {
                TripScoreCard(tripScore: tripScore, allBadges: result.allBadges)
            }

            // Travel DNA Card
            if let dna = result.travelDNA {
                TravelDNACard(dna: dna)
            }

            // Insights Preview
            if !result.insights.isEmpty {
                InsightsPreview(insights: result.insights, summary: result.insightSummary)
            }

            // Story Preview
            if let story = result.travelStory {
                StoryPreviewCard(story: story)
            }
        }
    }
}

// MARK: - Trip Score Card
struct TripScoreCard: View {
    let tripScore: MomentScoreService.TripOverallScore
    let allBadges: [MomentScoreService.SpecialBadge]

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 점수")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                // Star Rating
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(tripScore.starRating) ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(WanderColors.warning)
                    }
                }
            }

            HStack(spacing: WanderSpacing.space4) {
                // Score Circle
                ZStack {
                    Circle()
                        .stroke(WanderColors.border, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(tripScore.averageScore) / 100)
                        .stroke(gradeColor(for: tripScore.tripGrade), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(tripScore.averageScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(WanderColors.textPrimary)
                        Text("점")
                            .font(WanderTypography.caption2)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    // Grade Badge
                    HStack(spacing: WanderSpacing.space1) {
                        Text(tripScore.tripGrade.emoji)
                        Text(tripScore.tripGrade.koreanName)
                            .font(WanderTypography.headline)
                    }
                    .foregroundColor(gradeColor(for: tripScore.tripGrade))

                    // Summary
                    Text(tripScore.summary)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(2)

                    // Peak Moment
                    if tripScore.peakMomentScore > tripScore.averageScore {
                        Text("최고 순간: \(tripScore.peakMomentScore)점")
                            .font(WanderTypography.caption2)
                            .foregroundColor(WanderColors.primary)
                    }
                }

                Spacer()
            }

            // Badges
            if !allBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WanderSpacing.space2) {
                        ForEach(allBadges, id: \.self) { badge in
                            HStack(spacing: 4) {
                                Text(badge.emoji)
                                Text(badge.koreanName)
                                    .font(WanderTypography.caption2)
                            }
                            .padding(.horizontal, WanderSpacing.space2)
                            .padding(.vertical, 4)
                            .background(WanderColors.primaryPale)
                            .cornerRadius(WanderSpacing.radiusSmall)
                        }
                    }
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    private func gradeColor(for grade: MomentScoreService.MomentGrade) -> Color {
        switch grade {
        case .legendary: return Color(hex: "#FFD700") // Gold
        case .epic: return Color(hex: "#9B59B6") // Purple
        case .memorable: return WanderColors.primary
        case .pleasant: return WanderColors.success
        case .ordinary: return WanderColors.textSecondary
        case .casual: return WanderColors.textTertiary
        }
    }
}

// MARK: - Travel DNA Card
struct TravelDNACard: View {
    let dna: TravelDNAService.TravelDNA

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행자 DNA")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                // DNA Code
                Text(dna.dnaCode)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(WanderColors.primary)
                    .padding(.horizontal, WanderSpacing.space2)
                    .padding(.vertical, 4)
                    .background(WanderColors.primaryPale)
                    .cornerRadius(WanderSpacing.radiusSmall)
            }

            HStack(spacing: WanderSpacing.space4) {
                // Primary Type Icon
                VStack(spacing: WanderSpacing.space2) {
                    ZStack {
                        Circle()
                            .fill(WanderColors.primaryPale)
                            .frame(width: 60, height: 60)

                        Text(dna.primaryType.emoji)
                            .font(.system(size: 28))
                    }

                    Text(dna.primaryType.koreanName)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    // Description
                    Text(dna.description)
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(2)

                    // Stats
                    HStack(spacing: WanderSpacing.space3) {
                        DNAStatChip(label: "탐험", value: dna.explorationScore)
                        DNAStatChip(label: "문화", value: dna.cultureScore)
                        DNAStatChip(label: "소셜", value: dna.socialScore)
                    }
                }

                Spacer()
            }

            // Traits
            if !dna.traits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WanderSpacing.space2) {
                        ForEach(dna.traits, id: \.self) { trait in
                            HStack(spacing: 4) {
                                Text(trait.emoji)
                                Text(trait.koreanName)
                                    .font(WanderTypography.caption2)
                            }
                            .foregroundColor(WanderColors.textSecondary)
                            .padding(.horizontal, WanderSpacing.space2)
                            .padding(.vertical, 4)
                            .background(WanderColors.background)
                            .cornerRadius(WanderSpacing.radiusSmall)
                        }
                    }
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }
}

// MARK: - DNA Stat Chip
struct DNAStatChip: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WanderColors.textPrimary)
            Text(label)
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textTertiary)
        }
        .frame(width: 40)
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

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 스토리")
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
            NavigationLink(destination: AIStoryFullView(story: story)) {
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
