import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("설정 화면")
                    .wanderTitle1()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WanderColors.background)
            .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingsView()
}
