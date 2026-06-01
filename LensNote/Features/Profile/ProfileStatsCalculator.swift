//
//  ProfileStatsCalculator.swift
//  LensNote
//
//  Req 5 — 저장된 PhotoItem 목록으로부터 Profile 촬영 통계를 계산하는 순수 함수.
//

import Foundation

/// 촬영 통계 계산 결과.
struct ProfileStats: Equatable {
    /// 총 촬영(저장) 횟수.
    let totalPhotos: Int
    /// 가장 많이 사용한 ShotStyle. 동률 시 최근 촬영 기준. 스타일이 기록된 사진이 없으면 nil.
    let topShotStyle: ShotStyle?
    /// 가장 많이 사용한 FilterPreset 이름. 동률 시 최근 촬영 기준. 프리셋이 기록된 사진이 없으면 nil.
    let topFilterPreset: String?

    static let empty = ProfileStats(totalPhotos: 0, topShotStyle: nil, topFilterPreset: nil)
}

/// 순수 함수 — PhotoItem 배열로부터 통계를 계산한다(상태 없음, 테스트 용이).
enum ProfileStatsCalculator {
    static func compute(from items: [PhotoItem]) -> ProfileStats {
        ProfileStats(
            totalPhotos: items.count,
            topShotStyle: mostFrequent(in: items, key: { $0.shotStyle }),
            topFilterPreset: mostFrequent(in: items, key: { $0.filterPresetName })
        )
    }

    /// 빈도가 가장 높은 key를 반환한다. nil key(미기록)는 집계에서 제외.
    /// 동률이면 해당 key가 등장한 가장 최근 createdAt이 더 나중인 쪽을 택한다(Req 5.1).
    private static func mostFrequent<Key: Hashable>(
        in items: [PhotoItem],
        key: (PhotoItem) -> Key?
    ) -> Key? {
        var counts: [Key: Int] = [:]
        var latest: [Key: Date] = [:]
        for item in items {
            guard let k = key(item) else { continue }
            counts[k, default: 0] += 1
            if let current = latest[k] {
                latest[k] = max(current, item.createdAt)
            } else {
                latest[k] = item.createdAt
            }
        }
        return counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            // 동률 → 최근 촬영이 더 나중인 쪽을 우선.
            return (latest[lhs.key] ?? .distantPast) < (latest[rhs.key] ?? .distantPast)
        }?.key
    }
}
