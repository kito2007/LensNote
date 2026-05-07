//
//  SidePanelList.swift
//  LensNote
//

import SwiftUI

/// 사이드/바텀 패널 목록(썸네일+제목)
struct SidePanelList: View {
    let pins: [PhotoPin]
    @Binding var selection: UUID?
    private var displayedPins: [PhotoPin] { Array(pins.prefix(60)) }

    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxs) {
            HStack {
                Text("이 지역의 사진")
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text("\(pins.count)")
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.accentCyan)
            }
            .padding(.horizontal, LensNoteTheme.Spacing.xs)
            .padding(.top, LensNoteTheme.Spacing.xxs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayedPins) { pin in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selection = pin.id
                            }
                        } label: {
                            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                                PinThumbnailView(pin: pin, size: 48)
                                    .frame(width: 48, height: 48)
                                    .background(LensNoteTheme.Colors.surfaceHighest)
                                    .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pin.title)
                                        .font(LensNoteTheme.Typography.body)
                                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Text(pin.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(LensNoteTheme.Typography.technical)
                                        .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                                }
                            }
                            .padding(10)
                            .background(
                                selection == pin.id
                                    ? LensNoteTheme.Colors.primary.opacity(0.15)
                                    : LensNoteTheme.Colors.surfaceHigh
                            )
                            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
                            .shadow(color: LensNoteTheme.Shadow.ambient, radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, LensNoteTheme.Spacing.xs)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: 380)
        .background(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                .fill(LensNoteTheme.Colors.surfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        .shadow(color: LensNoteTheme.Shadow.elevated, radius: 10, y: 6)
    }
}
