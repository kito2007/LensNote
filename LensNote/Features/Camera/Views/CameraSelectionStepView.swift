//
//  CameraSelectionStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/21/26.
//

import SwiftUI

struct CameraSelectionStepView: View {
    
    let onSelectPhoto: () -> Void
    let onSelectText: () -> Void
    let onSelectManual: () -> Void
    let onSelectCamera: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxs) {
                Text("LensNote Camera")
                    .font(LensNoteTheme.Typography.heroTitle)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                Text("촬영 전 입력 방식을 선택하고 AI 어시스트를 시작하세요.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(LensNoteTheme.Colors.textSecondary)
            }

            VStack(spacing: LensNoteTheme.Spacing.xs) {
                modeButton(
                    title: "레퍼런스 사진 분석",
                    subtitle: "사진 톤을 분석해 추천값을 생성",
                    iconColor: LensNoteTheme.Colors.primary,
                    action: onSelectPhoto
                )

                modeButton(
                    title: "텍스트 컨셉 입력",
                    subtitle: "원하는 스타일 키워드로 시작",
                    iconColor: LensNoteTheme.Colors.accentCyan,
                    action: onSelectText
                )

                modeButton(
                    title: "수동 설정",
                    subtitle: "필터 값을 직접 조정",
                    iconColor: LensNoteTheme.Colors.success,
                    action: onSelectManual
                )

                // "카메라 바로 시작" — hero gradient accent
                Button(action: onSelectCamera) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("카메라 바로 시작")
                            .font(LensNoteTheme.Typography.title)
                        Text("기본값으로 즉시 촬영")
                            .font(LensNoteTheme.Typography.body)
                            .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                    }
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .padding(LensNoteTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LensNoteTheme.Colors.cardOverlayStrong)
                    .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                            .stroke(LensNoteTheme.Gradients.hero, lineWidth: 1.5)
                    )
                }
            }
            .padding(.top, LensNoteTheme.Spacing.xxs)

            Spacer(minLength: 0)
        }
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LensNoteTheme.Gradients.cameraBackground)
    }

    private func modeButton(
        title: String,
        subtitle: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: LensNoteTheme.Spacing.xs) {
                Circle()
                    .fill(iconColor.opacity(0.24))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(LensNoteTheme.Typography.title)
                    Text(subtitle)
                        .font(LensNoteTheme.Typography.body)
                        .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                }
            }
            .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            .padding(LensNoteTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LensNoteTheme.Colors.cardOverlay)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        }
    }
}
