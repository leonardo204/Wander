import SwiftUI

struct RecordsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("기록 목록")
                    .wanderTitle1()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WanderColors.background)
            .navigationTitle("기록")
        }
    }
}

#Preview {
    RecordsView()
}
