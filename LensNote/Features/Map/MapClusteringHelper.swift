//
//  MapClusteringHelper.swift
//  LensNote
//
//  Req 7 — MapView 분리. 핀 클러스터링/다운샘플링 순수 로직.
//

import MapKit

enum MapClusteringHelper {

    /// 영역 스케일에 따라 적응형 격자 크기를 계산하여 클러스터링(단일/클러스터 아이템 생성).
    /// region이 nil이면 전부 단일 핀으로 반환한다.
    static func buildClusters(from pins: [PhotoPin], in region: MKCoordinateRegion?) -> [ClusterItem] {
        guard let region else { return pins.map { ClusterItem(id: $0.id, kind: .single($0)) } }
        // 줌 레벨에 따른 격자 크기 결정
        let grid = max(Int(ceil(25.0 * (0.08 / max(region.span.latitudeDelta, 0.0005)))), 8)
        let latStep = max(region.span.latitudeDelta / Double(grid), 0.0005)
        let lonStep = max(region.span.longitudeDelta / Double(grid), 0.0005)

        var buckets: [String: [PhotoPin]] = [:]
        for pin in pins {
            let latBucket = Int(floor((pin.latitude - (region.center.latitude - region.span.latitudeDelta / 2)) / latStep))
            let lonBucket = Int(floor((pin.longitude - (region.center.longitude - region.span.longitudeDelta / 2)) / lonStep))
            let key = "\(latBucket)_\(lonBucket)"
            buckets[key, default: []].append(pin)
        }

        var items: [ClusterItem] = []
        for (_, group) in buckets {
            if group.count == 1, let pin = group.first {
                items.append(ClusterItem(id: pin.id, kind: .single(pin)))
            } else {
                let avgLat = group.map(\.latitude).reduce(0, +) / Double(group.count)
                let avgLon = group.map(\.longitude).reduce(0, +) / Double(group.count)
                let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
                items.append(ClusterItem(id: UUID(), kind: .cluster(center: center, pins: group)))
                // 3c — 반경 내 2개 이상 핀이 클러스터로 그룹화됨 (Req 11).
                AchievementLogger.passOnce("3c", "핀 클러스터링", detail: "\(group.count)개 그룹")
            }
        }
        return items
    }

    /// 핀이 너무 많을 때(>250) 격자 버킷으로 대표 핀만 남겨 UI 부하를 줄인다.
    static func downsample(_ pins: [PhotoPin], in region: MKCoordinateRegion) -> [PhotoPin] {
        guard pins.count > 250 else { return pins }

        let latStep = max(region.span.latitudeDelta / 25, 0.001)
        let lonStep = max(region.span.longitudeDelta / 25, 0.001)
        var buckets: [String: PhotoPin] = [:]

        for pin in pins {
            let latBucket = Int((pin.latitude / latStep).rounded(.down))
            let lonBucket = Int((pin.longitude / lonStep).rounded(.down))
            let key = "\(latBucket)_\(lonBucket)"
            if buckets[key] == nil {
                buckets[key] = pin
            }
        }

        return Array(buckets.values)
    }
}
