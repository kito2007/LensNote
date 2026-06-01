//
//  CameraCaptureResultStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/24/26.
//  Req 2 — 저장 전 확인 + 저장 후 결과 카드(위치명/프리셋/ShotStyle + 지도 이동).
//

import SwiftUI

struct CameraCaptureResultStepView: View {
    let capturedImage: UIImage?
    /// 저장 완료된 결과. nil이면 저장 전 확인 화면을 표시한다.
    let result: CaptureResultInfo?
    let errorMessage: String?

    let onBack: () -> Void
    let onRetake: () -> Void
    let onSave: () -> Void
    /// 결과 카드에서 새 촬영 시작.
    var onNewShot: () -> Void = {}
    /// 결과 카드의 "지도에서 보기".
    var onViewOnMap: () -> Void = {}

    var body: some View {
        VStack(spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                CameraBackButton(action: onBack)
                Spacer()
            }

            Spacer()

            photoPreview

            if let result {
                resultCard(result)
            } else {
                preSaveControls
            }

            Spacer()
        }
        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 배경은 Dynamic Island 뒤까지 채우고, 콘텐츠는 safe area 안에서 시작 (결함 1)
        .background(LensNoteTheme.Colors.surface, ignoresSafeAreaEdges: .all)
    }

    // MARK: - Photo preview

    private var previewImage: UIImage? { result?.thumbnail ?? capturedImage }

    private var photoPreview: some View {
        RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
            .fill(LensNoteTheme.Colors.cardOverlay)
            .overlay {
                if let previewImage {
                    Image(uiImage: previewImage)
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
            .frame(height: result == nil ? 320 : 240)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
    }

    // MARK: - Pre-save (저장 전 확인 / 저장 실패 재시도)

    @ViewBuilder
    private var preSaveControls: some View {
        if let err = errorMessage {
            // Req 2.4 — 저장 실패: 에러 + 재시도(이미지 유지 상태로 재저장).
            VStack(spacing: LensNoteTheme.Spacing.xs) {
                Label("저장에 실패했어요", systemImage: "exclamationmark.triangle.fill")
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.danger)
                Text(err)
                    .font(LensNoteTheme.Typography.technical)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.bottom, LensNoteTheme.Spacing.xxs)
        }

        HStack(spacing: LensNoteTheme.Spacing.xs) {
            Button("다시 찍기", action: onRetake)
                .buttonStyle(SecondaryCameraButtonStyle())

            Button(errorMessage == nil ? "저장하기" : "다시 시도", action: onSave)
                .buttonStyle(PrimaryCameraButtonStyle())
        }
    }

    // MARK: - Result card (저장 후)

    private func resultCard(_ result: CaptureResultInfo) -> some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xs) {
            Label("저장 완료", systemImage: "checkmark.circle.fill")
                .font(LensNoteTheme.Typography.bodyStrong)
                .foregroundStyle(LensNoteTheme.Colors.success)

            // 위치명 (역지오코딩, 진행 중이면 "위치 확인 중…")
            infoRow(
                icon: "mappin.and.ellipse",
                text: result.coordinate == nil
                    ? "위치 정보 없음"
                    : (result.placeName ?? "위치 확인 중…"),
                muted: result.coordinate == nil
            )

            // 적용된 프리셋
            if let preset = result.filterPresetName, !preset.isEmpty {
                infoRow(icon: "paintpalette.fill", text: preset, muted: false)
            }

            // ShotStyle 라벨 (레퍼런스 설정 시)
            if let style = result.shotStyleLabel {
                infoRow(icon: "camera.viewfinder", text: style, muted: false)
            }

            HStack(spacing: LensNoteTheme.Spacing.xs) {
                Button("새 촬영", action: onNewShot)
                    .buttonStyle(SecondaryCameraButtonStyle())

                Button("지도에서 보기", action: onViewOnMap)
                    .buttonStyle(PrimaryCameraButtonStyle())
                    .disabled(!result.canNavigateToMap)
                    .opacity(result.canNavigateToMap ? 1 : 0.5)
                    .accessibilityIdentifier("camera.result.view_on_map")
            }
            .padding(.top, LensNoteTheme.Spacing.xxs)
        }
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LensNoteTheme.Colors.cardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
    }

    private func infoRow(icon: String, text: String, muted: Bool) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(muted ? LensNoteTheme.Colors.textTertiary : LensNoteTheme.Colors.accentCyan)
                .frame(width: 20)
            Text(text)
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(muted ? LensNoteTheme.Colors.textTertiary : LensNoteTheme.Colors.textPrimary)
                .lineLimit(1)
        }
    }
}

private struct CameraCaptureResultStepPreviewWrapper: View {
    let capturedImage: UIImage?
    let result: CaptureResultInfo?
    let errorMessage: String?

    var body: some View {
        CameraCaptureResultStepView(
            capturedImage: capturedImage,
            result: result,
            errorMessage: errorMessage,
            onBack: {},
            onRetake: {},
            onSave: {}
        )
    }
}

#Preview("Pre-save") {
    CameraCaptureResultStepPreviewWrapper(
        capturedImage: UIImage(systemName: "photo.fill"),
        result: nil,
        errorMessage: nil
    )
}

#Preview("Result card") {
    CameraCaptureResultStepPreviewWrapper(
        capturedImage: UIImage(systemName: "photo.fill"),
        result: CaptureResultInfo(
            photoID: UUID(),
            thumbnail: UIImage(systemName: "photo.fill"),
            placeName: "서울특별시 종로구",
            filterPresetName: "Night Portrait",
            shotStyleLabel: "정면 셀피",
            coordinate: GeoCoordinate(latitude: 37.57, longitude: 126.98)
        ),
        errorMessage: nil
    )
}
