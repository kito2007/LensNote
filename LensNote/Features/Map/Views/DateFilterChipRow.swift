//
//  DateFilterChipRow.swift
//  LensNote
//
//  Req 6 — 지도 상단 기간 필터 칩 행.
//

import SwiftUI

struct DateFilterChipRow: View {
    let selected: DateRangeFilter
    let onSelect: (DateRangeFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LensNoteTheme.Spacing.xs) {
                ForEach(DateRangeFilter.allCases) { filter in
                    chip(filter)
                }
            }
            .padding(.horizontal, LensNoteTheme.Spacing.sm)
        }
    }

    private func chip(_ filter: DateRangeFilter) -> some View {
        let isActive = filter == selected
        return Button {
            onSelect(filter)
        } label: {
            Text(filter.label)
                .font(LensNoteTheme.Typography.chipLabel)
                .foregroundStyle(isActive ? LensNoteTheme.Colors.surface : LensNoteTheme.Colors.textTertiary)
                .padding(.horizontal, LensNoteTheme.Spacing.sm)
                .padding(.vertical, LensNoteTheme.Spacing.xxs)
                .background(isActive ? LensNoteTheme.Colors.accentCyan : LensNoteTheme.Colors.surfaceHigh)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(LensNoteTheme.Colors.chipBorder, lineWidth: isActive ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.filter.\(filter.rawValue)")
    }
}
