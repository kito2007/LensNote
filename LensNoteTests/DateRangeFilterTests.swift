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

    // MARK: - Property 3: 기간 포함 정확성 (Req 6.1, 6.2)

    /// 랜덤(결정론적) Date 100회 — 각 필터의 includes가 독립 계산한 경계와 일치하는지.
    @Test("Property 3: DateRangeFilter 기간 포함 정확성")
    func includesCorrectness() {
        let cal = calendar
        let now = now

        // 독립적으로 유도한 경계.
        let startToday = cal.startOfDay(for: now)
        let startTomorrow = cal.date(byAdding: .day, value: 1, to: startToday)!
        // 직전 월요일: weekday==2가 될 때까지 하루씩 후퇴.
        var weekStart = startToday
        while cal.component(.weekday, from: weekStart) != 2 {
            weekStart = cal.date(byAdding: .day, value: -1, to: weekStart)!
        }
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        for i in 0..<100 {
            // -45일 ~ +3일 범위를 시간 단위로 훑는다.
            let hoursOffset = (i * 27) % (48 * 24) - 45 * 24
            let date = cal.date(byAdding: .hour, value: hoursOffset, to: now)!

            #expect(DateRangeFilter.all.includes(date, now: now, calendar: cal) == true,
                    "all은 항상 true (i=\(i))")
            #expect(DateRangeFilter.today.includes(date, now: now, calendar: cal)
                    == (date >= startToday && date < startTomorrow),
                    "today (i=\(i) date=\(date))")
            #expect(DateRangeFilter.thisWeek.includes(date, now: now, calendar: cal)
                    == (date >= weekStart),
                    "thisWeek (i=\(i) date=\(date))")
            #expect(DateRangeFilter.thisMonth.includes(date, now: now, calendar: cal)
                    == (date >= monthStart),
                    "thisMonth (i=\(i) date=\(date))")
        }
    }

    @Test("월요일 주 시작 — 직전 월요일 00:00")
    func mondayWeekStart() {
        let cal = calendar
        // now = 수요일. 직전 월요일은 2026-06-01.
        let weekStart = DateRangeFilter.startOfWeekMonday(now, calendar: cal)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: weekStart)
        #expect(comps.year == 2026 && comps.month == 6 && comps.day == 1)
        #expect(comps.hour == 0 && comps.minute == 0 && comps.second == 0)
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
