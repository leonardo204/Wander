import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "InstagramShareService")

// MARK: - Instagram 공유 서비스

/// Instagram Feed 및 Stories 공유를 처리하는 서비스
final class InstagramShareService {

    // MARK: - Singleton

    static let shared = InstagramShareService()
    private init() {}

    // MARK: - URL Schemes

    private let instagramAppURLScheme = "instagram://"
    private let instagramStoriesURLScheme = "instagram-stories://share"
    private let appStoreURL = "https://apps.apple.com/app/instagram/id389801252"
    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.zerolive.wander"

    // MARK: - Public Methods

    /// Instagram 설치 여부 확인
    var isInstagramInstalled: Bool {
        guard let url = URL(string: instagramAppURLScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Instagram Feed 공유
    /// - Parameters:
    ///   - image: 공유할 이미지
    ///   - caption: 캡션 텍스트 (클립보드에 복사됨)
    /// - Note: Instagram은 외부 앱에서 캡션 직접 입력을 지원하지 않음
    @MainActor
    func shareToFeed(image: UIImage, caption: String) async throws {
        logger.info("📸 [InstagramShareService] Feed 공유 시작")

        guard isInstagramInstalled else {
            logger.warning("📸 [InstagramShareService] Instagram 미설치")
            throw ShareError.instagramNotInstalled
        }

        // 1. 캡션을 클립보드에 복사
        if !caption.isEmpty {
            UIPasteboard.general.string = caption
            logger.info("📸 [InstagramShareService] 캡션 클립보드 복사 완료")
        }

        // 2. 이미지를 사진 라이브러리에 저장
        try await saveImageToPhotoLibrary(image)

        // 3. Instagram 앱 열기 (사용자가 직접 갤러리에서 선택)
        guard let url = URL(string: instagramAppURLScheme) else {
            throw ShareError.unknown(NSError(domain: "InstagramShareService", code: -1))
        }

        await UIApplication.shared.open(url)
        logger.info("📸 [InstagramShareService] Instagram 앱 열림")
    }

    /// Instagram Stories 공유
    /// - Parameters:
    ///   - backgroundImage: 배경 이미지
    ///   - stickerImage: 스티커 이미지 (옵션)
    @MainActor
    func shareToStories(backgroundImage: UIImage, stickerImage: UIImage? = nil) async throws {
        logger.info("📸 [InstagramShareService] Stories 공유 시작")

        guard isInstagramInstalled else {
            logger.warning("📸 [InstagramShareService] Instagram 미설치")
            throw ShareError.instagramNotInstalled
        }

        // Pasteboard 아이템 구성
        var pasteboardItems: [String: Any] = [:]

        // 배경 이미지
        if let backgroundData = backgroundImage.pngData() {
            pasteboardItems["com.instagram.sharedSticker.backgroundImage"] = backgroundData
        }

        // 스티커 이미지 (옵션)
        if let sticker = stickerImage, let stickerData = sticker.pngData() {
            pasteboardItems["com.instagram.sharedSticker.stickerImage"] = stickerData
        }

        // Pasteboard에 설정 (5분 후 만료)
        UIPasteboard.general.setItems(
            [pasteboardItems],
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )

        // Instagram Stories URL Scheme 호출
        let urlString = "\(instagramStoriesURLScheme)?source_application=\(bundleIdentifier)"
        guard let url = URL(string: urlString) else {
            throw ShareError.unknown(NSError(domain: "InstagramShareService", code: -2))
        }

        guard UIApplication.shared.canOpenURL(url) else {
            throw ShareError.instagramNotInstalled
        }

        await UIApplication.shared.open(url)
        logger.info("📸 [InstagramShareService] Stories 열림")
    }

    /// App Store로 이동 (Instagram 설치)
    @MainActor
    func openAppStore() async {
        guard let url = URL(string: appStoreURL) else { return }
        await UIApplication.shared.open(url)
    }

    // MARK: - Private Methods

    /// 이미지를 사진 라이브러리에 저장
    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            // 저장 완료까지 약간의 딜레이
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
}

// MARK: - Instagram Share Alert

/// Instagram 미설치 시 표시할 알럿 뷰
struct InstagramNotInstalledAlert: View {
    @Binding var isPresented: Bool
    let onAppStoreOpen: () -> Void

    var body: some View {
        VStack(spacing: WanderSpacing.space4) {
            Image(systemName: "camera.circle")
                .font(.system(size: 48))
                .foregroundColor(WanderColors.primary)

            Text("Instagram이 설치되어 있지 않습니다")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            Text("Instagram에 공유하려면 앱을 설치해주세요.")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: WanderSpacing.space3) {
                Button("취소") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("App Store 열기") {
                    onAppStoreOpen()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(WanderColors.primary)
            }
            .padding(.top, WanderSpacing.space2)
        }
        .padding(WanderSpacing.space6)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusXXL)
        .shadow(color: .black.opacity(0.15), radius: 20)
    }
}

// MARK: - Instagram Share Guidance View

/// Instagram 공유 안내 뷰 (Feed 공유 시 표시)
struct InstagramShareGuidanceView: View {
    @Binding var isPresented: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: WanderSpacing.space5) {
            // 헤더
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(WanderColors.textTertiary)
                }
            }

            // 아이콘
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(WanderColors.primary)

            // 제목
            Text("캡션이 클립보드에 복사되었습니다")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            // 안내 단계
            VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                GuidanceStep(number: 1, text: "Instagram이 열리면 갤러리에서 저장된 이미지를 선택하세요")
                GuidanceStep(number: 2, text: "캡션 입력란에서 길게 눌러 '붙여넣기' 하세요")
                GuidanceStep(number: 3, text: "게시물을 공유하세요!")
            }
            .padding(.vertical, WanderSpacing.space2)

            // 계속 버튼
            Button(action: onContinue) {
                Text("Instagram 열기")
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
            }
        }
        .padding(WanderSpacing.space5)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusXXL)
    }
}

// MARK: - Guidance Step

private struct GuidanceStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: WanderSpacing.space3) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(WanderColors.primary)
                .clipShape(Circle())

            Text(text)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview("Instagram Guidance") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        InstagramShareGuidanceView(isPresented: .constant(true)) {
            print("Continue tapped")
        }
        .padding()
    }
}

#Preview("Instagram Not Installed") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        InstagramNotInstalledAlert(isPresented: .constant(true)) {
            print("App Store tapped")
        }
        .padding()
    }
}
