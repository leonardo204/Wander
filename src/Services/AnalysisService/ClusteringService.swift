import Foundation
import CoreLocation
import Photos
import DBSCAN
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ClusteringService")

/// GPS 사진 클러스터링 서비스 (v3.2: DBSCAN 밀도 기반)
/// NSHipster DBSCAN (MIT) + 시간 세그먼테이션 (trackintel 참조)
class ClusteringService {

    // MARK: - Parameters

    /// DBSCAN 공간 반경 (미터) - scikit-mobility 권장값
    private let spatialEpsilon: Double = 200

    /// DBSCAN 최소 포인트 수
    private let minPoints: Int = 1

    /// 시간 간격 임계값 (초) - 30분 이상 간격이면 세그먼트 분리
    private let timeGapThreshold: TimeInterval = 30 * 60

    /// 재방문 병합 반경 (미터)
    private let mergeRadius: Double = 200

    // MARK: - Main Clustering

    func cluster(photos: [PhotoMetadata]) -> [PlaceCluster] {
        logger.info("📍 [Clustering] DBSCAN cluster 호출 - 입력 사진: \(photos.count)장")
        guard !photos.isEmpty else {
            logger.warning("📍 [Clustering] 입력 사진 없음")
            return []
        }

        // Step 1: GPS 있는 사진만 필터, 시간순 정렬
        let gpsPhotos = photos.filter { $0.coordinate != nil }
            .sorted { ($0.capturedAt ?? Date()) < ($1.capturedAt ?? Date()) }

        guard !gpsPhotos.isEmpty else {
            logger.warning("📍 [Clustering] GPS 사진 없음")
            return []
        }

        logger.info("📍 [Clustering] GPS 사진: \(gpsPhotos.count)장")

        // Step 2: 시간 간격 기반 세그먼트 분리 (trackintel gap_threshold 개념)
        let timeSegments = splitByTimeGap(gpsPhotos)
        logger.info("📍 [Clustering] 시간 세그먼트: \(timeSegments.count)개")

        // Step 3: 세그먼트별 DBSCAN 클러스터링
        var allClusters: [PlaceCluster] = []
        for (i, segment) in timeSegments.enumerated() {
            let segmentClusters = dbscanCluster(segment)
            logger.info("📍 [Clustering] 세그먼트[\(i)]: 사진 \(segment.count)장 → 클러스터 \(segmentClusters.count)개")
            allClusters.append(contentsOf: segmentClusters)
        }

        // Step 4: 세그먼트 간 가까운 클러스터 병합 (같은 장소 재방문)
        let mergedClusters = mergeNearbyClusters(allClusters)
        logger.info("📍 [Clustering] 병합 후: \(mergedClusters.count)개 (병합 전: \(allClusters.count)개)")

        // Step 5: 단일 사진 클러스터 필터 (클러스터가 많을 때만)
        var result = mergedClusters
        if result.count > 3 {
            let beforeFilter = result.count
            result = result.filter { $0.photos.count >= 2 }
            logger.info("📍 [Clustering] 필터 후: \(result.count)개 (삭제: \(beforeFilter - result.count)개)")
        }

        logger.info("📍 [Clustering] 최종 클러스터: \(result.count)개")
        for (i, cluster) in result.enumerated() {
            logger.info("📍 [Clustering]   [\(i)]: 사진 \(cluster.photos.count)장, (\(String(format: "%.4f", cluster.latitude)), \(String(format: "%.4f", cluster.longitude)))")
        }

        return result
    }

    // MARK: - Time Segmentation (trackintel sliding window concept)

    /// 30분 이상 간격이 있으면 별도 시간 세그먼트로 분리
    private func splitByTimeGap(_ photos: [PhotoMetadata]) -> [[PhotoMetadata]] {
        guard !photos.isEmpty else { return [] }

        var segments: [[PhotoMetadata]] = []
        var currentSegment: [PhotoMetadata] = [photos[0]]

        for i in 1..<photos.count {
            let prevTime = photos[i - 1].capturedAt ?? Date()
            let currTime = photos[i].capturedAt ?? Date()
            let gap = currTime.timeIntervalSince(prevTime)

            if gap > timeGapThreshold {
                segments.append(currentSegment)
                currentSegment = [photos[i]]
            } else {
                currentSegment.append(photos[i])
            }
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments
    }

    // MARK: - DBSCAN Core

    /// NSHipster DBSCAN으로 공간 클러스터링
    private func dbscanCluster(_ photos: [PhotoMetadata]) -> [PlaceCluster] {
        guard !photos.isEmpty else { return [] }

        // 좌표 래퍼 생성 (DBSCAN에 인덱스를 전달하기 위함)
        let indexedCoords = photos.enumerated().compactMap { (index, photo) -> IndexedCoordinate? in
            guard let coord = photo.coordinate else { return nil }
            return IndexedCoordinate(index: index, latitude: coord.latitude, longitude: coord.longitude)
        }

        guard !indexedCoords.isEmpty else { return [] }

        // DBSCAN 실행 (Haversine 거리 함수, callAsFunction 패턴)
        let dbscan = DBSCAN(indexedCoords)
        let (clusters, _) = dbscan(
            epsilon: spatialEpsilon,
            minimumNumberOfPoints: minPoints,
            distanceFunction: { a, b in
                CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            }
        )

        // DBSCAN 클러스터 → PlaceCluster 변환
        return clusters.map { clusterCoords in
            buildPlaceCluster(from: photos, indexedCoordinates: clusterCoords)
        }
    }

    // MARK: - Cluster Building

    /// DBSCAN 결과에서 PlaceCluster 생성
    /// 중심 좌표는 중앙값(median) 사용 (scikit-mobility 권장, 평균보다 이상치에 강건)
    private func buildPlaceCluster(from photos: [PhotoMetadata], indexedCoordinates: [IndexedCoordinate]) -> PlaceCluster {
        // 중앙값 기반 중심 좌표 계산 (scikit-mobility stay_locations 방식)
        let lats = indexedCoordinates.map { $0.latitude }.sorted()
        let lons = indexedCoordinates.map { $0.longitude }.sorted()
        let medianLat = lats[lats.count / 2]
        let medianLon = lons[lons.count / 2]

        // 시간 범위
        let indices = indexedCoordinates.map { $0.index }
        let clusterPhotos = indices.compactMap { index -> PhotoMetadata? in
            guard index < photos.count else { return nil }
            return photos[index]
        }
        let times = clusterPhotos.compactMap { $0.capturedAt }
        let startTime = times.min() ?? Date()

        let cluster = PlaceCluster(
            latitude: medianLat,
            longitude: medianLon,
            startTime: startTime
        )

        // 사진 추가
        for photo in clusterPhotos {
            cluster.addPhoto(photo.asset)
        }

        return cluster
    }

    // MARK: - Cluster Merging

    /// 세그먼트 간 가까운 클러스터 병합 (같은 장소 재방문 처리)
    private func mergeNearbyClusters(_ clusters: [PlaceCluster]) -> [PlaceCluster] {
        guard clusters.count > 1 else { return clusters }

        var merged: [PlaceCluster] = []
        var used = Set<Int>()

        for i in 0..<clusters.count {
            guard !used.contains(i) else { continue }

            var current = clusters[i]
            used.insert(i)

            // 이후 클러스터 중 가까운 것 찾아 병합
            for j in (i + 1)..<clusters.count {
                guard !used.contains(j) else { continue }

                let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
                    .distance(from: CLLocation(latitude: clusters[j].latitude, longitude: clusters[j].longitude))

                if distance < mergeRadius {
                    // 병합: 사진 합치기, 중심점 재계산
                    let totalPhotos = current.photos.count + clusters[j].photos.count
                    let weight1 = Double(current.photos.count) / Double(totalPhotos)
                    let weight2 = Double(clusters[j].photos.count) / Double(totalPhotos)

                    current.latitude = current.latitude * weight1 + clusters[j].latitude * weight2
                    current.longitude = current.longitude * weight1 + clusters[j].longitude * weight2

                    for photo in clusters[j].photos {
                        current.addPhoto(photo)
                    }

                    // 시간 범위 확장
                    if let otherEnd = clusters[j].endTime, let currentEnd = current.endTime {
                        if otherEnd > currentEnd {
                            current.endTime = otherEnd
                        }
                    }

                    used.insert(j)
                }
            }

            merged.append(current)
        }

        return merged
    }
}

// MARK: - DBSCAN Helper Types

/// DBSCAN에 전달할 인덱스 포함 좌표 래퍼
/// DBSCAN 제네릭은 Equatable 필요
private struct IndexedCoordinate: Equatable {
    let index: Int
    let latitude: Double
    let longitude: Double

    static func == (lhs: IndexedCoordinate, rhs: IndexedCoordinate) -> Bool {
        lhs.index == rhs.index
    }
}
