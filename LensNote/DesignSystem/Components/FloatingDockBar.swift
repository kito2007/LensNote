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
        ZStack(alignment: .top) {
            // Layer 1: Bar pill (Home / Map / Profile buttons)
            barPill

            // Layer 2: Camera button elevated above the pill
            cameraButtonOverlay
        }
        .frame(height: barHeight + cameraElevation)
    }

    // MARK: - Bar Pill

    private var barPill: some View {
        HStack(alignment: .center, spacing: 0) {
            regularButton(.home)
            cameraButtonPlaceholder   // empty space to reserve camera slot
            regularButton(.map)
            regularButton(.profile)
        }
        .frame(height: barHeight)
        .background {
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
        }
        .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 8)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    // Invisible spacer matching camera button slot width
    private var cameraButtonPlaceholder: some View {
        Color.clear
            .frame(width: cameraButtonSize, height: barHeight)
    }

    // MARK: - Camera Button

    private var cameraButtonOverlay: some View {
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
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .top)
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
