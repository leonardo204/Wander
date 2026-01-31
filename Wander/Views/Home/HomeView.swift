import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("홈 화면")
                    .wanderTitle1()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WanderColors.background)
            .navigationTitle("Wander")
        }
    }
}

#Preview {
    HomeView()
}
