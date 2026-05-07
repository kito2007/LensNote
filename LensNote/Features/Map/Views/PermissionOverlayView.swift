//
//  PermissionOverlayView.swift
//  LensNote
//

import SwiftUI

/// 권한 안내 오버레이 — 지도 위 중앙에 반투명 카드로 표시
struct PermissionOverlayView: View {
    let state: MapViewModel.PermissionState
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: LensNoteTheme.Spacing.md) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(LensNoteTheme.Colors.warning)

            VStack(spacing: LensNoteTheme.Spacing.xxs) {
                Text(title)
                    .font(LensNoteTheme.Typography.cardTitle)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(LensNoteTheme.Typography.body)
                    .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if state != .missingUsageDescription {
                Button {
                    onOpenSettings()
                } label: {
                    Text("설정 열기")
                        .font(LensNoteTheme.Typography.bodyStrong)
                        .foregroundStyle(LensNoteTheme.Colors.accentCyan)
                        .padding(.horizontal, LensNoteTheme.Spacing.lg)
                        .padding(.vertical, LensNoteTheme.Spacing.xs)
                        .background(LensNoteTheme.Colors.accentCyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
                }
            }
        }
        .padding(LensNoteTheme.Spacing.xl)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                .fill(LensNoteTheme.Colors.surface.opacity(0.90))
                .overlay(
                    RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
        .shadow(color: LensNoteTheme.Shadow.elevated, radius: 16, y: 8)
    }

    private var title: String {
        switch state {
        case .denied:
            return "사진 접근 권한이 필요해요"
        case .restricted:
            return "사진 접근이 제한되어 있어요"
        case .missingUsageDescription:
            return "권한 설명 키가 필요해요"
        default:
            return "사진 접근 상태 확인"
        }
    }

    private var message: String {
        switch state {
        case .denied:
            return "지도에 사진을 표시하려면\n설정에서 사진 접근을 허용해주세요."
        case .restricted:
            return "기기 제한으로 사진 접근이 불가합니다."
        case .missingUsageDescription:
            return "Info.plist에 사진 권한 설명을 추가해주세요."
        default:
            return "권한 상태를 확인할 수 없습니다."
        }
    }
}

/// 로딩 상태 배너
struct LoadingBannerView: View {
    var body: some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            ProgressView()
                .controlSize(.small)
                .tint(LensNoteTheme.Colors.accentCyan)
            Text("사진을 불러오는 중...")
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
            Spacer()
        }
        .padding(LensNoteTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                .fill(LensNoteTheme.Colors.surfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        .shadow(color: LensNoteTheme.Shadow.ambient, radius: 6, y: 3)
    }
}
