//
//  CameraConceptStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/21/26.
//
import SwiftUI

struct CameraConceptStepView: View {
    @Binding var conceptInput: String

    let onBack: () -> Void
    let onStartCamera: () -> Void

    private var isStartDisabled: Bool {
        conceptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                backButton(action: onBack)
                Spacer()
            }

            Text("컨셉 입력")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            TextField("예: 야경, 인물, 풍경", text: $conceptInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)

            Button("카메라 시작", action: onStartCamera)
                .buttonStyle(PrimaryCameraButtonStyle())
                .disabled(isStartDisabled)
                .opacity(isStartDisabled ? 0.5 : 1)

            Spacer()
        }
        .padding(16)
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
}

private struct CameraConceptStepPreviewWrapper: View {
    @State private var conceptInput: String = "야경 인물"

    var body: some View {
        CameraConceptStepView(
            conceptInput: $conceptInput,
            onBack: {},
            onStartCamera: {}
        )
    }
}

#Preview {
    CameraConceptStepPreviewWrapper()
}
