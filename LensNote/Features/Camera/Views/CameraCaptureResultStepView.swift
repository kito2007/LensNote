//
//  CameraCaptureResultStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/24/26.
//

import SwiftUI

struct CameraCaptureResultStepView: View {
    let capturedImage: UIImage?
    let lastSaved: PhotoItem?
    let errorMessage: String?

    let onBack: () -> Void
    let onRetake: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                CameraBackButton(action: onBack)
                Spacer()
            }

            Spacer()

            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                .fill(LensNoteTheme.Colors.cardOverlay)
                .overlay {
                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: LensNoteTheme.Spacing.xxs) {
                            Image(systemName: "photo")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                            Text("Captured Preview")
                                .font(LensNoteTheme.Typography.bodyStrong)
                                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                        }
                    }
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))

            HStack(spacing: LensNoteTheme.Spacing.xs) {
                Button("다시 찍기", action: onRetake)
                    .buttonStyle(SecondaryCameraButtonStyle())

                Button("저장하기", action: onSave)
                    .buttonStyle(PrimaryCameraButtonStyle())
            }

            if let saved = lastSaved {
                Text("Saved: \(saved.id.uuidString.prefix(8))...")
                    .font(LensNoteTheme.Typography.technical)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }

            if let err = errorMessage {
                Text("Error: \(err)")
                    .font(LensNoteTheme.Typography.body)
                    .foregroundStyle(LensNoteTheme.Colors.danger)
            }

            Spacer()
        }
        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 배경은 Dynamic Island 뒤까지 채우고, 콘텐츠는 safe area 안에서 시작 (결함 1)
        .background(LensNoteTheme.Colors.surface, ignoresSafeAreaEdges: .all)
    }
}

private struct CameraCaptureResultStepPreviewWrapper: View {
    let capturedImage: UIImage?
    let lastSaved: PhotoItem?
    let errorMessage: String?

    var body: some View {
        CameraCaptureResultStepView(
            capturedImage: capturedImage,
            lastSaved: lastSaved,
            errorMessage: errorMessage,
            onBack: {},
            onRetake: {},
            onSave: {}
        )
    }
}

#Preview("Empty") {
    CameraCaptureResultStepPreviewWrapper(
        capturedImage: nil,
        lastSaved: nil,
        errorMessage: nil
    )
}

#Preview("Captured") {
    CameraCaptureResultStepPreviewWrapper(
        capturedImage: UIImage(systemName: "photo.fill"),
        lastSaved: nil,
        errorMessage: nil
    )
}
