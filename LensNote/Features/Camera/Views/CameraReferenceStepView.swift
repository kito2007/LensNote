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
        VStack(alignment: .leading, spacing: CameraDesign.sectionSpacing) {
            HStack {
                backButton(action: onBack)
                Spacer()
            }
            
            Text("레퍼런스 사진")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("참고 사진을 업로드하면 임시 분석값으로 카메라 모드를 시작합니다.")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.82))
            
            PhotosPicker(selection: $referencePickerItem, matching: .images, photoLibrary: .shared()) {
                Label("사진 선택", systemImage: "photo")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: CameraDesign.buttonRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            
            if let selectedReferenceImage {
                Image(uiImage: selectedReferenceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
            }
            
            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("분석 중...")
                        .font(.headline)
                }
                .padding(12)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
            }
            
            Spacer()
        }
        .padding(CameraDesign.screenPadding)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
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
