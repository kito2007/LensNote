//
//  ProfileView.swift
//  LensNote
//

import SwiftUI

// TODO: 유저 프로필, 설정, 통계 등 실제 기능 연동 예정
struct ProfileView: View {
    var body: some View {
        ZStack {
            LensNoteTheme.Colors.surface.ignoresSafeArea()

            VStack(spacing: LensNoteTheme.Spacing.md) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)

                Text("Profile")
                    .font(LensNoteTheme.Typography.sectionTitle)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                Text("Coming soon")
                    .font(LensNoteTheme.Typography.body)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
        }
    }
}

#Preview {
    ProfileView()
}
