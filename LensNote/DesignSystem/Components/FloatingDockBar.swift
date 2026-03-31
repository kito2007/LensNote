//
//  FloatingDockBar.swift
//  LensNote
//

import SwiftUI

struct FloatingDockBar: View {
    @Binding var selectedTab: AppTab
    @Namespace private var dockNamespace

    private let barHeight: CGFloat = 68
    private let cameraButtonSize: CGFloat = 56
    private let cameraElevation: CGFloat = 14
    private let regularIconSize: CGFloat = 22
    private let activePillWidth: CGFloat = 48
    private let activePillHeight: CGFloat = 32

    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Bar pill background — always 68pt tall, pinned to bottom
            barBackground

            // Layer 2: All 4 buttons in a single HStack
            // Camera button uses negative offset to float above the bar
            HStack(alignment: .bottom, spacing: 0) {
                regularButton(.home)
                cameraButton
                regularButton(.map)
                regularButton(.profile)
            }
            .frame(height: barHeight + cameraElevation)
        }
        .frame(height: barHeight + cameraElevation)
    }

    // MARK: - Bar Background

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: LensNoteTheme.Radius.dock, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: LensNoteTheme.Radius.dock, style: .continuous)
                    .fill(LensNoteTheme.Colors.surfaceLow.opacity(0.55))
            }
            .overlay {
                RoundedRectangle(cornerRadius: LensNoteTheme.Radius.dock, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .frame(height: barHeight)
            .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 8)
    }

    // MARK: - Camera Button (elevated)

    private var cameraButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = .camera
            }
        } label: {
            ZStack {
                Circle()
                    .fill(LensNoteTheme.Gradients.activeDock)
                    .frame(width: cameraButtonSize, height: cameraButtonSize)
                    .shadow(color: LensNoteTheme.Colors.primary.opacity(0.50), radius: 16, y: 6)

                if selectedTab == .camera {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                        .frame(width: cameraButtonSize, height: cameraButtonSize)
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            // 버튼 탭 영역은 bar 내 position에 유지하면서 시각적으로만 위로 돌출
            .offset(y: -cameraElevation)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Regular Button

    private func regularButton(_ tab: AppTab) -> some View {
        let isActive = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: LensNoteTheme.Radius.capsule)
                            .fill(LensNoteTheme.Gradients.activeDock)
                            .frame(width: activePillWidth, height: activePillHeight)
                            .matchedGeometryEffect(id: "activeTab", in: dockNamespace)
                    }

                    Image(systemName: tab.systemImage)
                        .font(.system(size: regularIconSize, weight: .semibold))
                        .foregroundStyle(isActive ? .white : LensNoteTheme.Colors.textTertiary)
                        .scaleEffect(isActive ? 1.05 : 1.0)
                }
                .frame(height: activePillHeight)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isActive)

                Text(tab.title)
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(isActive ? LensNoteTheme.Colors.textPrimary : LensNoteTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()
        VStack {
            Spacer()
            FloatingDockBar(selectedTab: .constant(.home))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
}
