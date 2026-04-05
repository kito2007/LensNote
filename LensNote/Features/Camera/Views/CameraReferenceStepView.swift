//
//  CameraReferenceStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/22/26.
//

import SwiftUI
import PhotosUI

struct CameraReferenceStepView: View {
    @Binding var referencePickerItem: PhotosPickerItem?
    let selectedReferenceImage: UIImage?
    let isAnalyzing: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                CameraBackButton(action: onBack)
                Spacer()
            }

            Text("레퍼런스 사진")
                .font(LensNoteTheme.Typography.sectionTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            Text("참고 사진을 업로드하면 임시 분석값으로 카메라 모드를 시작합니다.")
                .font(.system(size: 17))
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)

            PhotosPicker(selection: $referencePickerItem, matching: .images, photoLibrary: .shared()) {
                Label("사진 선택", systemImage: "photo")
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LensNoteTheme.Colors.cardOverlayStrong)
                    .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)

            if let selectedReferenceImage {
                Image(uiImage: selectedReferenceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
            }

            if isAnalyzing {
                HStack(spacing: LensNoteTheme.Spacing.xxs) {
                    ProgressView()
                        .tint(LensNoteTheme.Colors.accentCyan)
                    Text("분석 중...")
                        .font(LensNoteTheme.Typography.bodyStrong)
                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                }
                .padding(LensNoteTheme.Spacing.xs)
                .background(LensNoteTheme.Colors.cardOverlay)
                .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
            }

            Spacer()
        }
        .padding(LensNoteTheme.Spacing.sm)
        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LensNoteTheme.Colors.surface)
    }
}

private struct CameraReferenceStepPreviewWrapper: View {
    @State var referencePickerItem: PhotosPickerItem? = nil

    let selectedReferenceImage: UIImage?
    var isAnalyzing: Bool

    var body: some View {
        CameraReferenceStepView(
            referencePickerItem: $referencePickerItem,
            selectedReferenceImage: selectedReferenceImage,
            isAnalyzing: isAnalyzing,
            onBack: {}
        )
    }
}

#Preview("Empty") {
    CameraReferenceStepPreviewWrapper(
        selectedReferenceImage: nil,
        isAnalyzing: false
    )
}

#Preview("Analyzing") {
    CameraReferenceStepPreviewWrapper(
        selectedReferenceImage: UIImage(systemName: "photo"),
        isAnalyzing: true
    )
}

#Preview("Selected Image") {
    CameraReferenceStepPreviewWrapper(
        selectedReferenceImage: UIImage(systemName: "photo.fill"),
        isAnalyzing: false
    )
}
