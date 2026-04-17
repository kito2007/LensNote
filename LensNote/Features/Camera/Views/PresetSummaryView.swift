//
//  PresetSummaryView.swift
//  LensNote
//

import SwiftUI

/// FilterPreset을 노출/대비/채도/온도/비네트 바로 시각화하는 공용 카드.
/// - 레퍼런스 분석 완료 카드
/// - 컨셉 입력 실시간 미리보기
/// 두 곳에서 동일한 레이아웃을 공유한다.
struct PresetSummaryView: View {
    let preset: FilterPreset
    /// 제목 영역 노출 여부. 이미 상위 뷰가 제목을 렌더링하면 false.
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxs) {
            if showsTitle {
                HStack(spacing: LensNoteTheme.Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LensNoteTheme.Colors.accentCyan)
                    Text(preset.name)
                        .font(LensNoteTheme.Typography.title)
                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                }
            }

            VStack(spacing: 6) {
                presetBar(label: "노출", value: preset.exposure)
                presetBar(label: "대비", value: preset.contrast)
                presetBar(label: "채도", value: preset.saturation)
                presetBar(label: "온도", value: preset.temperature)
                presetBar(label: "비네트", value: preset.vignette)
            }
            .padding(.top, showsTitle ? 4 : 0)
        }
    }

    private func presetBar(label: String, value: Double) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Text(label)
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LensNoteTheme.Colors.cardOverlayStrong)
                        .frame(height: 4)

                    Rectangle()
                        .fill(LensNoteTheme.Colors.chipBorder)
                        .frame(width: 1, height: 8)
                        .position(x: trackWidth / 2, y: 2)

                    let normalized = max(-1, min(1, value))
                    let barWidth = abs(normalized) * trackWidth / 2
                    let startX = normalized >= 0 ? trackWidth / 2 : (trackWidth / 2 - barWidth)
                    Capsule()
                        .fill(LensNoteTheme.Colors.accentCyan)
                        .frame(width: barWidth, height: 4)
                        .offset(x: startX)
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            Text(formattedValue(value))
                .font(LensNoteTheme.Typography.technical)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func formattedValue(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))"
    }
}

#Preview {
    PresetSummaryView(
        preset: FilterPreset(
            name: "Cinematic",
            exposure: -0.1,
            contrast: 0.25,
            saturation: -0.05,
            temperature: -0.05,
            vignette: 0.4
        )
    )
    .padding()
    .background(LensNoteTheme.Colors.surface)
}
