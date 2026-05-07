//
//  ClusterBadgeView.swift
//  LensNote
//

import SwiftUI

/// 클러스터 개수 배지
struct ClusterBadgeView: View {
    let count: Int
    var body: some View {
        ZStack {
            Circle()
                .fill(LensNoteTheme.Colors.surfaceHighest)
                .overlay(Circle().fill(.ultraThinMaterial))
                .frame(width: 40, height: 40)
            Circle()
                .strokeBorder(LensNoteTheme.Colors.primary.opacity(0.5), lineWidth: 1)
                .frame(width: 40, height: 40)
            Text("\(count)")
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)
        }
        .shadow(color: LensNoteTheme.Shadow.ambient, radius: 3, y: 2)
    }
}
