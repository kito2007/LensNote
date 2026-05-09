//
//  CameraManualStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/22/26.
//

import SwiftUI

struct CameraManualStepView: View {
    let onBack: () -> Void
    let onStartCamera: () -> Void
    @Binding var manualExposure: Double
    @Binding var manualContrast: Double
    @Binding var manualSaturation: Double
    @Binding var manualTemperature: Double
    @Binding var manualVignette: Double

    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                CameraBackButton(action: onBack)
                Spacer()
            }

            Text("수동 필터 설정")
                .font(LensNoteTheme.Typography.sectionTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            manualSlider(title: "Exposure", value: $manualExposure)
            manualSlider(title: "Contrast", value: $manualContrast)
            manualSlider(title: "Saturation", value: $manualSaturation)
            manualSlider(title: "Temperature", value: $manualTemperature)
            manualSlider(title: "Vignette", value: $manualVignette, range: 0...1)

            Button("적용하고 카메라 시작", action: onStartCamera)
                .buttonStyle(PrimaryCameraButtonStyle())
                .padding(.top, LensNoteTheme.Spacing.xxs)

            Spacer()
        }
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 배경은 Dynamic Island 뒤까지 채우고, 콘텐츠는 safe area 안에서 시작 (결함 1)
        .background(LensNoteTheme.Colors.surface, ignoresSafeAreaEdges: .all)
    }

    private func manualSlider(title: String, value: Binding<Double>, range: ClosedRange<Double> = -1...1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(LensNoteTheme.Typography.technical)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
            Slider(value: value, in: range)
                .tint(LensNoteTheme.Colors.accentCyan)
        }
        .padding(LensNoteTheme.Spacing.xs)
        .background(LensNoteTheme.Colors.cardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
    }
}

private struct CameraManualStepPreviewWrapper: View {
    @State private var manualExposure: Double = 0.0
    @State private var manualContrast: Double = 0.0
    @State private var manualSaturation: Double = 0.0
    @State private var manualTemperature: Double = 0.0
    @State private var manualVignette: Double = 0.0

    var body: some View {
        CameraManualStepView(
            onBack: {}, onStartCamera: {},
            manualExposure: $manualExposure,
            manualContrast: $manualContrast,
            manualSaturation: $manualSaturation,
            manualTemperature: $manualTemperature,
            manualVignette: $manualVignette
        )
    }
}

#Preview {
    CameraManualStepPreviewWrapper()
}
