import Foundation
import CoreLocation
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ClusteringService")

class ClusteringService {
    // Clustering parameters
    private let distanceThreshold: Double = 100 // meters
    private let timeThreshold: TimeInterval = 30 * 60 // 30 minutes

    func cluster(photos: [PhotoMetadata]) -> [PlaceCluster] {
        logger.info("📍 [Clustering] cluster 호출 - 입력 사진: \(photos.count)장")
        guard !photos.isEmpty else {
            logger.warning("📍 [Clustering] 입력 사진 없음")
            return []
        }

        var clusters: [PlaceCluster] = []
        var currentCluster: PlaceCluster?

        for (index, photo) in photos.enumerated() {
            guard let coordinate = photo.coordinate else {
                logger.warning("📍 [Clustering] 사진[\(index)] GPS 없음, 스킵")
                continue
            }

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
                    logger.info("📍 [Clustering] 사진[\(index)] → 기존 클러스터에 추가 (거리: \(Int(distance))m)")

                    // Update cluster center (moving average)
                    let photoCount = Double(cluster.photos.count)
                    cluster.latitude = (cluster.latitude * (photoCount - 1) + coordinate.latitude) / photoCount
                    cluster.longitude = (cluster.longitude * (photoCount - 1) + coordinate.longitude) / photoCount
                } else {
                    // Save current cluster and start new one
                    logger.info("📍 [Clustering] 사진[\(index)] → 새 클러스터 시작 (거리: \(Int(distance))m, 시간차: \(Int(timeDiff/60))분)")
                    clusters.append(cluster)
                    currentCluster = createCluster(from: photo)
                }
            } else {
                // Start first cluster
                logger.info("📍 [Clustering] 사진[\(index)] → 첫 클러스터 시작")
                currentCluster = createCluster(from: photo)
            }
        }

        // Don't forget the last cluster
        if let lastCluster = currentCluster {
            clusters.append(lastCluster)
        }

        logger.info("📍 [Clustering] 필터 전 클러스터: \(clusters.count)개")

        // Filter out clusters with only 1 photo if there are multiple clusters
        if clusters.count > 3 {
            let beforeFilter = clusters.count
            clusters = clusters.filter { $0.photos.count >= 2 }
            logger.info("📍 [Clustering] 필터 후 클러스터: \(clusters.count)개 (삭제: \(beforeFilter - clusters.count)개)")
        }

        logger.info("📍 [Clustering] 최종 클러스터: \(clusters.count)개")
        for (i, cluster) in clusters.enumerated() {
            logger.info("📍 [Clustering]   클러스터[\(i)]: 사진 \(cluster.photos.count)장, 위치 (\(cluster.latitude), \(cluster.longitude))")
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
