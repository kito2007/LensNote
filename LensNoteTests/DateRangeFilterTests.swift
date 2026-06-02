//
//  DateRangeFilterTests.swift
//  LensNoteTests
//
//  Req 6 — Property 3(기간 포함 정확성) + Property 4(필터 변경 시 무효 선택 해제).
//

import Testing
import Foundation
@testable import LensNote

struct DateRangeFilterTests {

    /// 고정 타임존 캘린더 — 결정론적 경계 계산.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }

    /// 기준 now: 2026-06-03(수요일) 15:30 KST.
    private var now: Date {
        var c = calendar
        return c.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 15, minute: 30))!
    }

    // MARK: - Property 3: 롤링 윈도우 포함 정확성 + 중첩 (Req 6.1, 6.2)

    /// 랜덤(결정론적) Date 100회 — 각 필터의 롤링 윈도우 [now-W, now] 포함이 정확하고,
    /// today ⊆ thisWeek ⊆ thisMonth ⊆ all 중첩이 항상 성립한다.
    @Test("Property 3: 롤링 윈도우 포함 + 중첩")
    func rollingWindowInclusionAndNesting() {
        let now = now
        let day = 86_400.0

        for i in 0..<100 {
            // -40일 ~ +1일 범위를 시간 단위로 훑는다(미래 약간 포함).
            let hoursOffset = Double((i * 27) % (41 * 24)) - 40 * 24
            let date = now.addingTimeInterval(hoursOffset * 3600)
            let delta = now.timeIntervalSince(date)   // 양수면 과거

            let inToday = delta >= 0 && delta <= 24 * 3600
            let inWeek = delta >= 0 && delta <= 7 * day
            let inMonth = delta >= 0 && delta <= 30 * day

            #expect(DateRangeFilter.all.includes(date, now: now) == true, "all (i=\(i))")
            #expect(DateRangeFilter.today.includes(date, now: now) == inToday, "today (i=\(i) delta=\(delta))")
            #expect(DateRangeFilter.thisWeek.includes(date, now: now) == inWeek, "week (i=\(i) delta=\(delta))")
            #expect(DateRangeFilter.thisMonth.includes(date, now: now) == inMonth, "month (i=\(i) delta=\(delta))")

            // 중첩 보장: 좁은 윈도우에 들면 넓은 윈도우에도 든다.
            if DateRangeFilter.today.includes(date, now: now) {
                #expect(DateRangeFilter.thisWeek.includes(date, now: now), "today⊆week (i=\(i))")
            }
            if DateRangeFilter.thisWeek.includes(date, now: now) {
                #expect(DateRangeFilter.thisMonth.includes(date, now: now), "week⊆month (i=\(i))")
            }
        }
    }

    @Test("미래 날짜는 all에만 포함")
    func futureDateOnlyInAll() {
        let future = now.addingTimeInterval(3600) // 1시간 뒤
        #expect(DateRangeFilter.all.includes(future, now: now))
        #expect(!DateRangeFilter.today.includes(future, now: now))
        #expect(!DateRangeFilter.thisWeek.includes(future, now: now))
        #expect(!DateRangeFilter.thisMonth.includes(future, now: now))
    }

    @Test("경계: 정확히 24시간/7일/30일 전은 포함")
    func windowBoundariesInclusive() {
        let day = 86_400.0
        #expect(DateRangeFilter.today.includes(now.addingTimeInterval(-24 * 3600), now: now))
        #expect(DateRangeFilter.thisWeek.includes(now.addingTimeInterval(-7 * day), now: now))
        #expect(DateRangeFilter.thisMonth.includes(now.addingTimeInterval(-30 * day), now: now))
        // 윈도우 밖
        #expect(!DateRangeFilter.today.includes(now.addingTimeInterval(-24 * 3600 - 1), now: now))
    }

    // MARK: - Property 4: 필터 변경 시 무효 선택 해제 (Req 6.6)

    private func pin(createdAt: Date) -> PhotoPin {
        PhotoPin(
            id: UUID(),
            latitude: 37.5,
            longitude: 127.0,
            title: "t",
            createdAt: createdAt,
            assetLocalIdentifier: nil,
            thumbnail: nil,
            source: .lensNote
        )
    }

    /// 랜덤 createdAt 핀 + 필터 전환 100회 — 선택 유지 여부가 includes 결과와 정확히 일치.
    /// created는 정확한 일(day) 단위 배수라 주/월 경계(00:00)가 안정적이라 플레이키하지 않다.
    @MainActor
    @Test("Property 4: 필터 변경 시 무효 선택 해제")
    func filterChangeClearsInvalidSelection() {
        let filters = DateRangeFilter.allCases

        for i in 0..<100 {
            let daysAgo = Double((i * 11) % 60)               // 0~59일 전
            let created = Date().addingTimeInterval(-daysAgo * 86_400)
            let p = pin(createdAt: created)
            let filter = filters[i % filters.count]

            let vm = MapViewModel()
            vm.select(pin: p)
            #expect(vm.selectedPin?.id == p.id)

            let included = filter.includes(created)
            vm.applyDateFilter(filter)

            #expect((vm.selectedPin != nil) == included,
                    "선택 유지=\(vm.selectedPin != nil)인데 includes=\(included) (i=\(i) filter=\(filter) daysAgo=\(daysAgo))")
        }
    }

    @Test("all 필터는 선택을 항상 유지")
    @MainActor
    func allFilterKeepsSelection() {
        let p = pin(createdAt: Date().addingTimeInterval(-365 * 86_400))
        let vm = MapViewModel()
        vm.select(pin: p)
        vm.applyDateFilter(.all)
        #expect(vm.selectedPin?.id == p.id)
    }
}
