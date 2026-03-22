//
//  CameraManualStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/22/26.
//

import SwiftUI

struct CameraManualStepView: View{
    let onBack: () -> Void
    let onStartCamera: () -> Void
    @Binding var manualExposure: Double
    @Binding var manualContrast: Double
    @Binding var manualSaturation: Double
    @Binding var manualTemperature: Double
    @Binding var manualVignette: Double
    
    var body: some View{
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                backButton(action: onBack)
                Spacer()
            }
            
            Text("수동 필터 설정")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            
            manualSlider(title: "Exposure", value: $manualExposure)
            manualSlider(title: "Contrast", value: $manualContrast)
            manualSlider(title: "Saturation", value: $manualSaturation)
            manualSlider(title: "Temperature", value: $manualTemperature)
            manualSlider(title: "Vignette", value: $manualVignette, range: 0...1)

            Button("적용하고 카메라 시작", action: onStartCamera)
            .buttonStyle(PrimaryCameraButtonStyle())
            .padding(.top, 8)

            Spacer()
            
        }.padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel("뒤로")
    }
    private func manualSlider(title: String, value: Binding<Double>, range: ClosedRange<Double> = -1...1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }
            Slider(value: value, in: range)
                .tint(.cyan)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
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
            onBack: {}, onStartCamera: {}, manualExposure: $manualExposure, manualContrast: $manualContrast, manualSaturation: $manualSaturation, manualTemperature: $manualTemperature, manualVignette: $manualVignette
        )
    }
}

#Preview {
    CameraManualStepPreviewWrapper()
}
