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
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                CameraBackButton(action: onBack)
                Spacer()
            }

            Text("컨셉 입력")
                .font(LensNoteTheme.Typography.sectionTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            TextField("예: 야경, 인물, 풍경", text: $conceptInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(LensNoteTheme.Spacing.sm)
                .background(LensNoteTheme.Colors.cardOverlay)
                .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            Button("카메라 시작", action: onStartCamera)
                .buttonStyle(PrimaryCameraButtonStyle())
                .disabled(isStartDisabled)
                .opacity(isStartDisabled ? 0.5 : 1)

            Spacer()
        }
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LensNoteTheme.Colors.surface)
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
