//
//  PinAnnotationView.swift
//  LensNote
//

import SwiftUI

/// 지도 핀 아이콘 뷰 — source에 따라 LensNote 핀과 라이브러리 핀을 다르게 표현한다.
struct PinAnnotationView: View {
    let selected: Bool
    let source: PhotoPinSource

    var body: some View {
        ZStack {
            switch source {
            case .lensNote:
                lensNotePin
            case .library:
                libraryPin
            }
        }
        .accessibilityLabel(source == .lensNote ? "LensNote 촬영 사진" : "라이브러리 사진")
    }

    /// LensNote 고유 핀: 진한 primary 배경, camera.aperture 뱃지, 선택 시 cyan glow
    private var lensNotePin: some View {
        ZStack {
            // 선택 시 cyan glow 링
            if selected {
                Circle()
                    .fill(LensNoteTheme.Colors.accentCyan.opacity(0.28))
                    .frame(width: 64, height: 64)
                    .transition(.scale)
            }

            // 메인 원형 배경
            Circle()
                .fill(LensNoteTheme.Colors.primary)
                .frame(width: 48, height: 48)
                .shadow(color: LensNoteTheme.Colors.primary.opacity(0.55), radius: selected ? 10 : 4, y: 2)

            // accentCyan 포인터 dot
            Circle()
                .fill(LensNoteTheme.Colors.accentCyan)
                .frame(width: 8, height: 8)
                .offset(y: 20)

            // camera.aperture 아이콘
            Image(systemName: "camera.aperture")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            // 좌상단 뱃지
            Image(systemName: "camera.aperture")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(3)
                .background(LensNoteTheme.Colors.accentCyan)
                .clipShape(Circle())
                .offset(x: -14, y: -14)
        }
        .frame(width: 64, height: 64)
    }

    /// 라이브러리 핀: surfaceHighest 배경, 조용한 스타일
    private var libraryPin: some View {
        ZStack {
            if selected {
                Circle().fill(LensNoteTheme.Colors.primary.opacity(0.22))
                    .frame(width: 52, height: 52)
                    .transition(.scale)
            }

            Circle()
                .fill(LensNoteTheme.Colors.surfaceHighest)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(LensNoteTheme.Colors.textSecondary, lineWidth: 0.8)
                        .frame(width: 40, height: 40)
                )
                .shadow(color: LensNoteTheme.Shadow.ambient, radius: 3, y: 1)

            Image(systemName: selected ? "mappin.circle.fill" : "mappin.circle")
                .font(.system(size: 16))
                .foregroundStyle(selected ? LensNoteTheme.Colors.primary : LensNoteTheme.Colors.textSecondary)
        }
        .frame(width: 52, height: 52)
    }
}
