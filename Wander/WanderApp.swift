import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "WanderApp")

@main
struct WanderApp: App {
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @State private var showSplash = true

    var sharedModelContainer: ModelContainer = {
        logger.info("🚀 [WanderApp] ModelContainer 생성 시작")
        let schema = Schema([
            TravelRecord.self,
            TravelDay.self,
            Place.self,
            PhotoItem.self
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
        }
        .modelContainer(sharedModelContainer)
    }
}
