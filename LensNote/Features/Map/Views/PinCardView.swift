//
//  PinCardView.swift
//  LensNote
//

import SwiftUI

/// 하단 상세 카드(썸네일/제목/시간/소스)
struct PinCardView: View {
    let pin: PhotoPin
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: LensNoteTheme.Spacing.xs) {
            thumbnail

            VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxxs) {
                // 소스 뱃지
                Text(pin.source == .lensNote ? "LENSNOTE" : "LIBRARY")
                    .font(LensNoteTheme.Typography.microLabel)
                    .tracking(0.8)
                    .foregroundStyle(
                        pin.source == .lensNote
                            ? LensNoteTheme.Colors.accentCyan
                            : LensNoteTheme.Colors.textTertiary
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (pin.source == .lensNote
                            ? LensNoteTheme.Colors.accentCyan
                            : LensNoteTheme.Colors.textTertiary
                        ).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(pin.title)
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(pin.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(LensNoteTheme.Typography.technical)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
            .accessibilityLabel("닫기")
        }
        .padding(LensNoteTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                .fill(LensNoteTheme.Colors.surfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
        .shadow(color: LensNoteTheme.Shadow.elevated, radius: 8, y: 4)
    }

    private var thumbnail: some View {
        PinThumbnailView(pin: pin, size: 56)
            .frame(width: 56, height: 56)
            .background(LensNoteTheme.Colors.surfaceHighest)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
    }
}
