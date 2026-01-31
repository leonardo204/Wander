import Foundation
import CoreLocation
import Photos

class ClusteringService {
    // Clustering parameters
    private let distanceThreshold: Double = 100 // meters
    private let timeThreshold: TimeInterval = 30 * 60 // 30 minutes

    func cluster(photos: [PhotoMetadata]) -> [PlaceCluster] {
        guard !photos.isEmpty else { return [] }

        var clusters: [PlaceCluster] = []
        var currentCluster: PlaceCluster?

        for photo in photos {
            guard let coordinate = photo.coordinate else { continue }

            if let cluster = currentCluster {
                let clusterLocation = CLLocation(
                    latitude: cluster.latitude,
                    longitude: cluster.longitude
                )
                let photoLocation = CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )

                let distance = clusterLocation.distance(from: photoLocation)
                let timeDiff = (photo.capturedAt ?? Date()).timeIntervalSince(cluster.endTime ?? cluster.startTime)

                // Check if photo belongs to current cluster
                if distance < distanceThreshold && timeDiff < timeThreshold {
                    // Add to current cluster
                    cluster.addPhoto(photo.asset)

                    // Update cluster center (moving average)
                    let photoCount = Double(cluster.photos.count)
                    cluster.latitude = (cluster.latitude * (photoCount - 1) + coordinate.latitude) / photoCount
                    cluster.longitude = (cluster.longitude * (photoCount - 1) + coordinate.longitude) / photoCount
                } else {
                    // Save current cluster and start new one
                    clusters.append(cluster)
                    currentCluster = createCluster(from: photo)
                }
            } else {
                // Start first cluster
                currentCluster = createCluster(from: photo)
            }
        }

        // Don't forget the last cluster
        if let lastCluster = currentCluster {
            clusters.append(lastCluster)
        }

        // Filter out clusters with only 1 photo if there are multiple clusters
        if clusters.count > 3 {
            clusters = clusters.filter { $0.photos.count >= 2 }
        }

        return clusters
    }

    private func createCluster(from photo: PhotoMetadata) -> PlaceCluster {
        let cluster = PlaceCluster(
            latitude: photo.latitude ?? 0,
            longitude: photo.longitude ?? 0,
            startTime: photo.capturedAt ?? Date()
        )
        cluster.addPhoto(photo.asset)
        return cluster
    }
}
