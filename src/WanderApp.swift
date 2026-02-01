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

    var sharedModelContainer: ModelContainer = {
        logger.info("🚀 [WanderApp] ModelContainer 생성 시작")
        let schema = Schema([
            TravelRecord.self,
            TravelDay.self,
            Place.self,
            PhotoItem.self,
            RecordCategory.self,
            UserPlace.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
            .preferredColorScheme(.light)  // 라이트모드 고정
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - URL Handling
    private func handleIncomingURL(_ url: URL) {
        logger.info("🔗 [WanderApp] URL 수신: \(url.absoluteString)")

        // wander://share?data=BASE64_ENCODED_DATA
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
}
