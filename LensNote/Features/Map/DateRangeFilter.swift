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

    /// 윈도우 길이(초). 롤링 방식이라 항상 today ⊆ thisWeek ⊆ thisMonth ⊆ all 로 중첩된다.
    /// (캘린더 경계 방식은 월 초에 "이번 주"가 "이번 달"보다 넓어지는 역전이 생겨 롤링으로 정의.)
    private var window: TimeInterval? {
        switch self {
        case .all:       return nil          // 무제한
        case .today:     return 24 * 3600     // 최근 24시간
        case .thisWeek:  return 7 * 86_400    // 최근 7일
        case .thisMonth: return 30 * 86_400   // 최근 30일
        }
    }

    /// 주어진 날짜가 이 필터의 롤링 윈도우 [now - window, now] 안에 있는지 판정한다.
    /// all은 항상 true. (calendar 파라미터는 시그니처 호환을 위해 유지하며 롤링에서는 사용하지 않는다.)
    func includes(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let window else { return true }            // .all
        return date >= now.addingTimeInterval(-window) && date <= now
    }
}
