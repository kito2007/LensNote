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
                    topBar
                    introSection
                    heroCard
                    quickActionsSection
                    pendingSectionsPlaceholder
                }
                .padding(.horizontal, LensNoteTheme.Spacing.lg)
                .padding(.vertical, LensNoteTheme.Spacing.xl)
            }
            .background(LensNoteTheme.Colors.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var topBar: some View {
        HStack {
            Label {
                Text("LENSNOTE")
                    .font(.system(size: 20, weight: .black))
                    .tracking(-0.4)
            } icon: {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(LensNoteTheme.Colors.primary)

            Spacer()

            Circle()
                .fill(LensNoteTheme.Colors.surfaceHigh)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                }
        }
        .padding(.vertical, LensNoteTheme.Spacing.xxs)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xs) {
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                .textCase(.uppercase)

            Text("오늘의 촬영을 시작해볼까요")
                .font(LensNoteTheme.Typography.heroTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            Label("카메라, 레퍼런스 분석, 기록 탐색을 한 화면에서 시작", systemImage: "location.north.line")
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
        }
    }

    private var heroCard: some View {
        Button(action: onUploadReference) {
            ZStack(alignment: .topTrailing) {
                LensNoteTheme.Gradients.hero
                    .overlay {
                        RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                            .fill(.white.opacity(0.08))
                            .blur(radius: 12)
                    }

                Image(systemName: "sparkles")
                    .font(.system(size: 100, weight: .light))
                    .foregroundStyle(.white.opacity(0.16))
                    .padding(.top, LensNoteTheme.Spacing.lg)
                    .padding(.trailing, LensNoteTheme.Spacing.md)

                VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.md) {
                    Text("AI POWERED")
                        .font(LensNoteTheme.Typography.microLabel)
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, LensNoteTheme.Spacing.xs)
                        .padding(.vertical, LensNoteTheme.Spacing.xxs)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxs) {
                        Text("Match the\nVision")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(.white)

                        Text("레퍼런스 이미지를 업로드하면 LensNote가 촬영 방향과 무드 설정의 시작점을 잡아줍니다.")
                            .font(LensNoteTheme.Typography.body)
                            .foregroundStyle(.white.opacity(0.84))
                            .frame(maxWidth: 220, alignment: .leading)
                    }

                    Label("Upload Reference", systemImage: "square.and.arrow.up.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LensNoteTheme.Colors.surface)
                        .padding(.horizontal, LensNoteTheme.Spacing.md)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(LensNoteTheme.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
            .shadow(color: LensNoteTheme.Shadow.elevated, radius: 32, y: 16)
        }
        .buttonStyle(.plain)
    }

    private var quickActionsSection: some View {
        VStack(spacing: LensNoteTheme.Spacing.sm) {
            quickActionCard(
                title: "Quick Shot",
                subtitle: "즉시 촬영 흐름으로 이동",
                description: "빠르게 카메라를 열고 현재 장면을 바로 캡처",
                icon: "camera.fill",
                actionTitle: "Open Camera",
                action: onOpenCamera
            )

            quickActionCard(
                title: "Map Gallery",
                subtitle: "촬영 기록 탐색으로 이동",
                description: "저장된 결과와 위치 기록을 한 번에 훑어보기",
                icon: "map.fill",
                actionTitle: "Open Gallery",
                action: onOpenMapGallery
            )
        }
    }

    private var pendingSectionsPlaceholder: some View {
        Text("다음 커밋에서 Captured Moments, Recent Sessions 섹션 추가 예정")
            .font(LensNoteTheme.Typography.body)
            .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            .padding(LensNoteTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LensNoteTheme.Colors.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
    }

    private func quickActionCard(
        title: String,
        subtitle: String,
        description: String,
        icon: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LensNoteTheme.Colors.primary.opacity(0.20))

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LensNoteTheme.Colors.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxxs) {
                Text(title)
                    .font(LensNoteTheme.Typography.cardTitle)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textSecondary)

                Text(description)
                    .font(LensNoteTheme.Typography.body)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }

            Button(actionTitle, action: action)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LensNoteTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LensNoteTheme.Colors.surfaceHighest)
                .overlay {
                    RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous)
                        .stroke(LensNoteTheme.Colors.primary.opacity(0.18), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
        }
        .padding(LensNoteTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LensNoteTheme.Colors.surfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
    }
}

#Preview {
    HomeView(
        onUploadReference: {},
        onOpenCamera: {},
        onOpenMapGallery: {}
    )
}
