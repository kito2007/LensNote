//
//  ProfileView.swift
//  LensNote
//
//  Req 5 — 촬영 통계(총 촬영/최다 ShotStyle/최다 Preset)를 표시하는 Profile 탭.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        ZStack {
            LensNoteTheme.Colors.surface.ignoresSafeArea()

            VStack(spacing: LensNoteTheme.Spacing.lg) {
                header

                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .tint(LensNoteTheme.Colors.accentCyan)
                        .frame(maxHeight: .infinity)
                case .empty:
                    emptyState
                case .failed:
                    errorState
                case .loaded(let stats):
                    statsList(stats)
                }

                Spacer(minLength: 0)
            }
            .padding(LensNoteTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: LensNoteTheme.Spacing.xs) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)
            Text("내 기록")
                .font(LensNoteTheme.Typography.sectionTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        }
        .padding(.top, LensNoteTheme.Spacing.md)
    }

    // MARK: - Stats

    private func statsList(_ stats: ProfileStats) -> some View {
        VStack(spacing: LensNoteTheme.Spacing.sm) {
            statCard(
                icon: "camera.fill",
                title: "총 촬영",
                value: "\(stats.totalPhotos)장"
            )
            statCard(
                icon: stats.topShotStyle?.symbolName ?? "camera.viewfinder",
                title: "가장 많이 쓴 스타일",
                value: stats.topShotStyle?.koreanDescription ?? "기록 없음"
            )
            statCard(
                icon: "paintpalette.fill",
                title: "가장 많이 쓴 프리셋",
                value: stats.topFilterPreset ?? "기록 없음"
            )
        }
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)
                .frame(width: 44, height: 44)
                .background(LensNoteTheme.Colors.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                Text(value)
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(LensNoteTheme.Colors.cardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
    }

    // MARK: - Empty / Error

    private var emptyState: some View {
        VStack(spacing: LensNoteTheme.Spacing.sm) {
            Image(systemName: "photo.stack")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            Text("아직 촬영한 사진이 없어요")
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
            Text("카메라로 첫 사진을 남겨보세요.")
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
        }
        .frame(maxHeight: .infinity)
    }

    private var errorState: some View {
        VStack(spacing: LensNoteTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(LensNoteTheme.Colors.warning)
            Text("통계를 불러올 수 없어요")
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
            Button("다시 시도") { viewModel.load() }
                .font(LensNoteTheme.Typography.bodyStrong)
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)
        }
        .frame(maxHeight: .infinity)
    }
}
