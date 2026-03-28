//
//  CameraCaptureResultStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/24/26.
//

import SwiftUI

struct CameraCaptureResultStepView: View{
    let capturedImage: UIImage?
    let lastSaved: PhotoItem?
    let errorMessage: String?
    
    let onBack: () -> Void
    let onRetake: () -> Void
    let onSave: () -> Void
    
    var body: some View{
        VStack(spacing: CameraDesign.sectionSpacing) {
            HStack {
                backButton(action: onBack)
                Spacer()
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 44, weight: .medium))
                            Text("Captured Preview")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                }
                .frame(height: 320)
                .clipped()
            
            HStack(spacing: 12) {
                Button("다시 찍기", action: onRetake)
                .buttonStyle(SecondaryCameraButtonStyle())
                
                Button("저장하기", action: onSave)
                .buttonStyle(PrimaryCameraButtonStyle())
            }
            
            if let saved = lastSaved {
                Text("Saved: \(saved.id.uuidString.prefix(8))...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            if let err = errorMessage {
                Text("Error: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(CameraDesign.screenPadding)
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

private struct CamraCaptureResultStepPreviewWrapper: View {
    let capturedImage: UIImage?
    let lastSaved: PhotoItem?
    let errorMessage: String?

    var body: some View{
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
    CamraCaptureResultStepPreviewWrapper(
        capturedImage: nil,
        lastSaved: nil,
        errorMessage: nil
    )
}

#Preview("Captured") {
    CamraCaptureResultStepPreviewWrapper(
        capturedImage: UIImage(systemName: "photo.fill"),
        lastSaved: nil,
        errorMessage: nil
    )
}
