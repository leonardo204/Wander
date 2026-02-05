import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "DeepLinkHandler")

// MARK: - Deep Link Handler

/// 앱 딥링크 처리 관리자
@MainActor
final class DeepLinkHandler: ObservableObject {

    static let shared = DeepLinkHandler()

    // MARK: - Published

    /// 수신된 공유 URL (UI에서 observe)
    @Published var pendingShareURL: URL?

    /// 공유 수신 시트 표시 여부
    @Published var showShareReceiveSheet = false

    // MARK: - Init

    private init() {
        logger.debug("🔗 DeepLinkHandler 초기화")
    }

    // MARK: - Handle URL

    /// URL 처리
    /// - Parameter url: 딥링크 URL
    /// - Returns: 처리 성공 여부
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        logger.info("🔗 URL 수신: \(url.absoluteString)")

        // 공유 링크인지 확인
        if isShareLink(url) {
            return handleShareLink(url)
        }

        // 다른 딥링크 타입 처리 (향후 확장)
        logger.warning("⚠️ 알 수 없는 딥링크: \(url.absoluteString)")
        return false
    }

    // MARK: - Share Link

    /// 공유 링크 여부 확인
    private func isShareLink(_ url: URL) -> Bool {
        // Universal Link: https://wander.zerolive.com/share/{shareID}
        if url.scheme == "https" && url.host == "wander.zerolive.com" {
            return url.pathComponents.contains("share")
        }

        // Custom Scheme: wander://share/{shareID}
        if url.scheme == "wander" && url.host == "share" {
            return true
        }

        return false
    }

    /// 공유 링크 처리
    private func handleShareLink(_ url: URL) -> Bool {
        logger.info("🔗 공유 링크 처리 시작")

        // URL 파싱 검증
        guard let deepLink = ShareDeepLink.parse(from: url) else {
            logger.error("❌ 공유 링크 파싱 실패")
            return false
        }

        logger.info("✅ 공유 링크 파싱 성공 (shareID: \(deepLink.shareID))")

        // 공유 수신 화면 표시
        pendingShareURL = url
        showShareReceiveSheet = true

        return true
    }

    // MARK: - Clear

    /// 대기 중인 공유 URL 초기화
    func clearPendingShare() {
        pendingShareURL = nil
        showShareReceiveSheet = false
    }
}
