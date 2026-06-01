//
//  DateRangeFilter.swift
//  LensNote
//
//  Req 6 — 지도 기간 필터. 순수 로직(includes)으로 테스트 가능.
//

import Foundation

/// 지도 핀을 촬영 기간으로 거르는 필터. 기기 로컬 타임존(전달된 calendar) 기준.
enum DateRangeFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case thisWeek
    case thisMonth

    var id: String { rawValue }

    /// 칩에 표시할 라벨.
    var label: String {
        switch self {
        case .all:       return "전체"
        case .today:     return "오늘"
        case .thisWeek:  return "이번 주"
        case .thisMonth: return "이번 달"
        }
    }

    /// 주어진 날짜가 이 필터 기간에 포함되는지 판정한다.
    /// - today: now와 같은 캘린더 날짜
    /// - thisWeek: 직전 월요일 00:00 이후
    /// - thisMonth: 당월 1일 00:00 이후
    /// - all: 항상 true
    func includes(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .thisWeek:
            return date >= Self.startOfWeekMonday(now, calendar: calendar)
        case .thisMonth:
            return date >= Self.startOfMonth(now, calendar: calendar)
        }
    }

    // MARK: - Boundaries

    /// 직전 월요일 00:00:00. (calendar.firstWeekday와 무관하게 월요일 고정.)
    static func startOfWeekMonday(_ now: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: now)
        // weekday: 1=일 … 7=토. 월요일(2)로부터 경과 일수.
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }

    /// 당월 1일 00:00:00.
    static func startOfMonth(_ now: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: now)
    }
}
