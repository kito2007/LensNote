//
//  ProfileStatsCalculatorTests.swift
//  LensNoteTests
//
//  Req 5 — Property 8: Profile statistics computation (Req 5.1).
//

import Testing
import Foundation
@testable import LensNote

struct ProfileStatsCalculatorTests {

    // MARK: - Helpers

    private func item(
        style: ShotStyle?,
        preset: String?,
        createdAt: Date
    ) -> PhotoItem {
        PhotoItem(
            id: UUID(),
            createdAt: createdAt,
            imagePath: "/tmp/x.jpg",
            coordinate: nil,
            shotStyle: style,
            filterPresetName: preset
        )
    }

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// key별 (count, 가장 최근 createdAt)를 독립적으로 집계 — 구현과 분리된 검증용.
    private func tally<Key: Hashable>(_ items: [PhotoItem], _ key: (PhotoItem) -> Key?) -> [Key: (count: Int, latest: Date)] {
        var result: [Key: (count: Int, latest: Date)] = [:]
        for it in items {
            guard let k = key(it) else { continue }
            if let cur = result[k] {
                result[k] = (cur.count + 1, max(cur.latest, it.createdAt))
            } else {
                result[k] = (1, it.createdAt)
            }
        }
        return result
    }

    /// 최다 빈도 key가 맞는지(동률이면 더 최근) 검증하는 불변식.
    private func assertTopIsValid<Key: Hashable>(
        _ top: Key?,
        tallied: [Key: (count: Int, latest: Date)],
        _ label: String
    ) {
        if tallied.isEmpty {
            #expect(top == nil, "\(label): 기록 없으면 nil이어야 함")
            return
        }
        guard let top, let chosen = tallied[top] else {
            Issue.record("\(label): top이 nil이거나 집계에 없음")
            return
        }
        let maxCount = tallied.values.map(\.count).max()!
        #expect(chosen.count == maxCount, "\(label): 최다 빈도가 아님 (\(chosen.count) != \(maxCount))")
        // 동률 후보 중 chosen.latest가 가장 나중이어야 함.
        for (_, v) in tallied where v.count == maxCount {
            #expect(chosen.latest >= v.latest, "\(label): 동률인데 더 최근 후보가 존재")
        }
    }

    // MARK: - Property 8

    /// 랜덤(결정론적) PhotoItem 배열 100회 — totalPhotos / topShotStyle / topFilterPreset 정확성.
    @Test("Property 8: Profile 통계 계산 정확성")
    func profileStatsCorrectness() {
        let styles: [ShotStyle?] = [.classicSelfie, .landscape, .closeUp, .wideSelfie, nil]
        let presets: [String?] = ["Vivid", "Noir", "Warm", nil]

        for i in 0..<100 {
            let n = (i % 9) + 1               // 1~9개
            var items: [PhotoItem] = []
            for j in 0..<n {
                let style = styles[(i * 7 + j * 3) % styles.count]
                let preset = presets[(i * 5 + j * 2) % presets.count]
                // createdAt을 매번 다르게 — 동률 tie-break를 다양하게 만든다.
                let t = base.addingTimeInterval(Double((i * 13 + j * 29) % 97))
                items.append(item(style: style, preset: preset, createdAt: t))
            }

            let stats = ProfileStatsCalculator.compute(from: items)

            #expect(stats.totalPhotos == items.count, "i=\(i) totalPhotos")
            assertTopIsValid(stats.topShotStyle, tallied: tally(items) { $0.shotStyle }, "i=\(i) shotStyle")
            assertTopIsValid(stats.topFilterPreset, tallied: tally(items) { $0.filterPresetName }, "i=\(i) preset")
        }
    }

    // MARK: - 명시적 케이스

    @Test("빈 배열 → empty 통계")
    func emptyArray() {
        let stats = ProfileStatsCalculator.compute(from: [])
        #expect(stats == ProfileStats.empty)
    }

    @Test("동률 시 최근 촬영 우선")
    func tieBreaksByRecency() {
        // classicSelfie 1장(오래됨) vs landscape 1장(최근) — 동률이면 최근 landscape.
        let items = [
            item(style: .classicSelfie, preset: "A", createdAt: base),
            item(style: .landscape, preset: "B", createdAt: base.addingTimeInterval(100))
        ]
        let stats = ProfileStatsCalculator.compute(from: items)
        #expect(stats.topShotStyle == .landscape)
        #expect(stats.topFilterPreset == "B")
    }

    @Test("nil 스타일/프리셋은 집계 제외")
    func nilsExcluded() {
        let items = [
            item(style: nil, preset: nil, createdAt: base),
            item(style: nil, preset: nil, createdAt: base.addingTimeInterval(10)),
            item(style: .closeUp, preset: "Solo", createdAt: base.addingTimeInterval(20))
        ]
        let stats = ProfileStatsCalculator.compute(from: items)
        #expect(stats.totalPhotos == 3)
        #expect(stats.topShotStyle == .closeUp)
        #expect(stats.topFilterPreset == "Solo")
    }
}
