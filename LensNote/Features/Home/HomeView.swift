//
//  HomeView.swift
//  LensNote
//
//  Created by Codex on 3/29/26.
//

import SwiftUI

struct HomeView: View {
    let onUploadReference: () -> Void
    let onOpenCamera: () -> Void
    let onOpenMapGallery: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.lg) {
                    headerSection

                    VStack(spacing: LensNoteTheme.Spacing.sm) {
                        actionButton(
                            title: "레퍼런스 업로드",
                            subtitle: "AI 가이드 촬영을 시작할 사진 기반 진입점",
                            systemImage: "sparkles.rectangle.stack",
                            action: onUploadReference
                        )

                        actionButton(
                            title: "카메라 열기",
                            subtitle: "바로 촬영 흐름으로 이동",
                            systemImage: "camera.fill",
                            action: onOpenCamera
                        )

                        actionButton(
                            title: "맵 갤러리 보기",
                            subtitle: "촬영 기록과 위치 기반 탐색으로 이동",
                            systemImage: "map.fill",
                            action: onOpenMapGallery
                        )
                    }

                    Text("다음 커밋에서 Stitch 홈 시안의 Hero / Quick Shot / Recent Sessions 구성을 이 화면 위에 올릴 예정입니다.")
                        .font(LensNoteTheme.Typography.body)
                        .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                        .padding(LensNoteTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LensNoteTheme.Colors.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
                }
                .padding(.horizontal, LensNoteTheme.Spacing.lg)
                .padding(.vertical, LensNoteTheme.Spacing.xl)
            }
            .background(LensNoteTheme.Colors.surface.ignoresSafeArea())
            .navigationTitle("LensNote")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xs) {
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                .textCase(.uppercase)

            Text("오늘의 촬영을 시작해볼까요")
                .font(LensNoteTheme.Typography.heroTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            Text("LensNote 홈 허브에서 카메라, 레퍼런스 분석, 기록 탐색 흐름을 정리합니다.")
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
        }
    }

    private func actionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: LensNoteTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(LensNoteTheme.Colors.cardOverlayStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxxs) {
                    Text(title)
                        .font(LensNoteTheme.Typography.title)
                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(LensNoteTheme.Typography.body)
                        .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
            .padding(LensNoteTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LensNoteTheme.Colors.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(
        onUploadReference: {},
        onOpenCamera: {},
        onOpenMapGallery: {}
    )
}
