//
//  CameraButtonStyles.swift
//  LensNote
//
//  Created by 박태영 on 3/21/26.
//

import SwiftUI

struct PrimaryCameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LensNoteTheme.Typography.bodyStrong)
            .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(LensNoteTheme.Gradients.hero)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .shadow(color: LensNoteTheme.Shadow.elevated, radius: 18, x: 0, y: 10)
    }
}

struct SecondaryCameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LensNoteTheme.Typography.bodyStrong)
            .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(LensNoteTheme.Colors.surfaceHighest.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous)
                    .stroke(LensNoteTheme.Colors.primary.opacity(0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            .frame(width: 36, height: 36)
            .background(LensNoteTheme.Colors.glassOverlay)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
