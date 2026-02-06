import SwiftUI
import Photos

struct GridLayoutView: View {
    let places: [PlaceCluster]

    let columns = [
        GridItem(.flexible(), spacing: WanderSpacing.space3),
        GridItem(.flexible(), spacing: WanderSpacing.space3)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("장소 모아보기")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            LazyVGrid(columns: columns, spacing: WanderSpacing.space3) {
                ForEach(places) { place in
                    GridCard(place: place)
                }
            }
        }
    }
}

struct GridCard: View {
    let place: PlaceCluster
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(WanderColors.surface)
                    .frame(height: 120)
                    .overlay(ProgressView())
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.displayName)
                    .font(WanderTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(WanderColors.textPrimary)
                    .lineLimit(1)

                HStack {
                    Text(place.displayEmoji)
                    Text(activityLabel)
                }
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textSecondary)
            }
            .padding(WanderSpacing.space2)
            .background(Color.white)
        }
        .cornerRadius(WanderSpacing.radiusMedium)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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

    private func loadImage() {
        guard let asset = place.photos.first else { return }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            self.image = img
        }
    }
}
