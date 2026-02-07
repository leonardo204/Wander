import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "WanderApp")

@main
struct WanderApp: App {
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @State private var showSplash = true
    @State private var sharedRecordData: SharedRecordData?
    @State private var showSharedRecord = false

    // P2P 공유 관련
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @State private var savedSharedRecord: TravelRecord?

    var sharedModelContainer: ModelContainer = {
        logger.info("🚀 [WanderApp] ModelContainer 생성 시작")
        let schema = Schema([
            TravelRecord.self,
            TravelDay.self,
            Place.self,
            PhotoItem.self,
            RecordCategory.self,
            UserPlace.self,
            LearnedPlace.self  // v3.1: 자동 학습된 장소 패턴
        ])
        // CloudKit 동기화 비활성화 (P2P 공유는 Public DB를 직접 사용)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // SwiftData-CloudKit 동기화 비활성화
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            logger.info("🚀 [WanderApp] ModelContainer 생성 성공")
            return container
        } catch {
            logger.error("🚀 [WanderApp] ModelContainer 생성 실패: \(error.localizedDescription)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isOnboardingCompleted {
                    ContentView()
                } else {
                    OnboardingContainerView()
                }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                logger.info("🚀 [WanderApp] 앱 시작 - isOnboardingCompleted: \(self.isOnboardingCompleted)")

                // v3.2: 레거시 LearnedPlace 정리 (H3 인덱스 없는 레코드 삭제)
                cleanupLegacyLearnedPlaces()

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        logger.info("🚀 [WanderApp] 스플래시 종료")
                        showSplash = false
                    }
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .sheet(isPresented: $showSharedRecord) {
                if let data = sharedRecordData {
                    SharedRecordView(sharedData: data)
                }
            }
            // P2P 공유 수신 시트
            .sheet(isPresented: $deepLinkHandler.showShareReceiveSheet) {
                if let shareURL = deepLinkHandler.pendingShareURL {
                    P2PShareReceiveView(
                        shareURL: shareURL,
                        onSaveComplete: { record in
                            savedSharedRecord = record
                            deepLinkHandler.clearPendingShare()
                            // 저장 완료 후 기록 탭으로 이동 등 추가 처리 가능
                        }
                    )
                }
            }
            .preferredColorScheme(.light)  // 라이트모드 고정
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - URL Handling
    private func handleIncomingURL(_ url: URL) {
        logger.info("🔗 [WanderApp] URL 수신: \(url.absoluteString)")

        // P2P 공유 링크 확인 (CloudKit 기반)
        // Universal Link: https://wander.zerolive.com/share/{shareID}?key={key}
        // Custom Scheme: wander://share/{shareID}?key={key}
        if isP2PShareLink(url) {
            logger.info("🔗 [WanderApp] P2P 공유 링크 감지")
            deepLinkHandler.handleURL(url)
            return
        }

        // 기존 방식: wander://share?data=BASE64_ENCODED_DATA (레거시)
        guard url.scheme == "wander" else {
            logger.warning("🔗 [WanderApp] 지원하지 않는 URL 스킴: \(url.scheme ?? "nil")")
            return
        }

        guard url.host == "share" else {
            logger.warning("🔗 [WanderApp] 지원하지 않는 URL 호스트: \(url.host ?? "nil")")
            return
        }

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let base64Data = dataItem.value else {
            logger.error("🔗 [WanderApp] URL에서 데이터를 찾을 수 없음")
            return
        }

        // Decode shared data
        if let decoded = SharedRecordData.decode(from: base64Data) {
            logger.info("🔗 [WanderApp] 공유 데이터 디코딩 성공: \(decoded.title)")
            sharedRecordData = decoded
            showSharedRecord = true
        } else {
            logger.error("🔗 [WanderApp] 공유 데이터 디코딩 실패")
        }
    }

    // MARK: - Legacy Data Cleanup

    /// v3.2: H3 인덱스가 없는 레거시 LearnedPlace 레코드 삭제
    /// 이전 버전에서 행정구역 문자열 기반으로 생성된 레코드를 정리하고 재학습 유도
    private func cleanupLegacyLearnedPlaces() {
        let context = sharedModelContainer.mainContext
        do {
            let descriptor = FetchDescriptor<LearnedPlace>()
            let allPlaces = try context.fetch(descriptor)

            let legacyPlaces = allPlaces.filter { $0.h3CellRes9.isEmpty }
            guard !legacyPlaces.isEmpty else { return }

            logger.info("🚀 [WanderApp] 레거시 LearnedPlace 정리: \(legacyPlaces.count)개 삭제")
            for place in legacyPlaces {
                context.delete(place)
            }
            try context.save()
            logger.info("🚀 [WanderApp] 레거시 LearnedPlace 정리 완료")
        } catch {
            logger.warning("🚀 [WanderApp] LearnedPlace 정리 실패: \(error.localizedDescription)")
        }
    }

    /// P2P 공유 링크인지 확인
    private func isP2PShareLink(_ url: URL) -> Bool {
        // Universal Link with key parameter
        if url.scheme == "https" && url.host == "wander.zerolive.com" {
            if url.pathComponents.contains("share"),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               components.queryItems?.contains(where: { $0.name == "key" }) == true {
                return true
            }
        }

        // Custom Scheme with key parameter (not legacy data parameter)
        if url.scheme == "wander" && url.host == "share" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               components.queryItems?.contains(where: { $0.name == "key" }) == true {
                return true
            }
        }

        return false
    }
}
