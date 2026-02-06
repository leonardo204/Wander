import SwiftUI

// MARK: - AI Enhancement Sheet

struct AIEnhancementSheet: View {
    @Binding var isEnhancing: Bool
    @Binding var enhancementError: String?
    let onEnhance: (AIProvider) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: AIProvider?

    /// API 키 또는 OAuth가 설정된 프로바이더 목록
    private var configuredProviders: [AIProvider] {
        var providers = AIProvider.allCases.filter { provider in
            (try? KeychainManager.shared.getAPIKey(for: provider.keychainType)) != nil
        }
        if GoogleOAuthService.shared.isAuthenticated && !providers.contains(.google) {
            providers.append(.google)
        }
        return providers
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space6) {
                // 설명
                VStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(WanderColors.primary)

                    Text("AI로 다듬기")
                        .font(WanderTypography.title2)

                    Text("규칙 기반으로 생성된 텍스트를\n자연스럽고 감성적으로 다듬어줍니다.")
                        .font(WanderTypography.bodySmall)
                        .foregroundColor(WanderColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, WanderSpacing.space4)

                // 프로바이더 선택
                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    Text("AI 서비스 선택")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)

                    ForEach(configuredProviders) { provider in
                        Button {
                            selectedProvider = provider
                        } label: {
                            HStack {
                                Text(provider.displayName)
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textPrimary)

                                Spacer()

                                if selectedProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(WanderColors.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(WanderColors.textTertiary)
                                }
                            }
                            .padding(WanderSpacing.space3)
                            .background(selectedProvider == provider ? WanderColors.primaryPale : WanderColors.surface)
                            .cornerRadius(WanderSpacing.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                                    .stroke(selectedProvider == provider ? WanderColors.primary : WanderColors.border, lineWidth: 1)
                            )
                        }
                    }
                }

                // 에러 메시지
                if let error = enhancementError {
                    HStack(spacing: WanderSpacing.space1) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(WanderColors.error)
                        Text(error)
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.error)
                    }
                    .padding(WanderSpacing.space3)
                    .background(WanderColors.errorBackground)
                    .cornerRadius(WanderSpacing.radiusMedium)
                }

                // 프라이버시 안내
                HStack(spacing: WanderSpacing.space1) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12))
                    Text("장소명, 시간 정보만 전송됩니다. 사진은 전송되지 않습니다.")
                        .font(WanderTypography.caption2)
                }
                .foregroundColor(WanderColors.textTertiary)

                Spacer()

                // 다듬기 시작 버튼
                Button {
                    if let provider = selectedProvider {
                        onEnhance(provider)
                    }
                } label: {
                    Text("다듬기 시작")
                        .font(WanderTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: WanderSpacing.buttonHeight)
                        .background(selectedProvider != nil ? WanderColors.primary : WanderColors.textTertiary)
                        .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(selectedProvider == nil)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.bottom, WanderSpacing.space4)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .onAppear {
            // 프로바이더가 1개면 자동 선택
            if configuredProviders.count == 1 {
                selectedProvider = configuredProviders.first
            }
        }
    }
}
