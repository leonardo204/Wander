import SwiftUI
import SwiftData

@main
struct WanderApp: App {
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @State private var showSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TravelRecord.self,
            TravelDay.self,
            Place.self,
            PhotoItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
