import SwiftUI
import Photos

struct MagazineLayoutView: View {
    let places: [PlaceCluster]
    var context: TravelContext = .travel

    /// Context에 따른 매거진 제목
    private var magazineTitle: String {
        switch context {
        case .travel: return "여행 매거진"
        case .outing: return "외출 매거진"
        case .daily: return "오늘의 기록"
        case .mixed: return "매거진"
        }
    }

    var body: some View {
        VStack(spacing: WanderSpacing.space5) {
            Text(magazineTitle)
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(places) { place in
                MagazineCard(place: place)
            }
        }
    }
}

struct MagazineCard: View {
    let place: PlaceCluster
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo Area
            ZStack(alignment: .bottomLeading) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(WanderColors.surface)
                        .frame(height: 300)
                        .overlay(ProgressView())
                }

                // Overlay Gradient
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 100)

                // Info Overlay
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(place.displayEmoji)
                        Text(place.displayName)
                            .font(WanderTypography.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)

                    HStack {
                        Text(formatTime(place.startTime))
                        Text("·")
                        Text(activityLabel)
                    }
                    .font(WanderTypography.caption1)
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(WanderSpacing.space4)
            }

            // Description / Photos count
            HStack {
                if !place.address.isEmpty {
                    Image(systemName: "mappin.and.ellipse")
                    Text(place.address)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "photo")
                Text("\(place.photos.count)장")
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.textSecondary)
            .padding(WanderSpacing.space3)
            .background(WanderColors.surface)
        }
        .cornerRadius(WanderSpacing.radiusLarge)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .onAppear {
            loadImage()
        }
    }

    // 활동 라벨
    private var activityLabel: String {
        if let scene = place.sceneCategory, scene != .unknown {
            return scene.koreanName
        }
        return place.activityType.displayName
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }

    private func loadImage() {
        guard let asset = place.photos.first else { return }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 600, height: 600),
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            self.image = img
        }
    }
}
