//
//  MapEmptyStateView.swift
//  LensNote
//

import SwiftUI

/// 핀이 없을 때 표시되는 빈 상태 안내
struct MapEmptyStateView: View {
    var onCameraTabTap: (() -> Void)?

    var body: some View {
        VStack(spacing: LensNoteTheme.Spacing.md) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)

            VStack(spacing: LensNoteTheme.Spacing.xxs) {
                Text("아직 저장된 사진이 없어요")
                    .font(LensNoteTheme.Typography.cardTitle)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("카메라로 사진을 찍으면\n이 지도에 표시됩니다")
                    .font(LensNoteTheme.Typography.body)
                    .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let onCameraTabTap {
                Button {
                    onCameraTabTap()
                } label: {
                    HStack(spacing: LensNoteTheme.Spacing.xxs) {
                        Image(systemName: "camera.fill")
                        Text("카메라로 이동")
                    }
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.accentCyan)
                    .padding(.horizontal, LensNoteTheme.Spacing.lg)
                    .padding(.vertical, LensNoteTheme.Spacing.xs)
                    .background(LensNoteTheme.Colors.accentCyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
                }
            }
        }
        .padding(LensNoteTheme.Spacing.xl)
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                .fill(LensNoteTheme.Colors.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
        .shadow(color: LensNoteTheme.Shadow.elevated, radius: 16, y: 8)
    }
}
