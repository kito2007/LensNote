//
//  LensNoteTheme.swift
//  LensNote
//
//  Created by Codex on 3/28/26.
//

import SwiftUI

enum LensNoteTheme {
    enum Colors {
        // Midnight Obsidian surface hierarchy — depth via tonal layering, no borders
        static let surface = Color(red: 0.0745, green: 0.0745, blue: 0.0824)   // #131315
        static let surfaceLow = Color(red: 0.098, green: 0.098, blue: 0.110)
        static let surfaceHigh = Color(red: 0.145, green: 0.145, blue: 0.165)
        static let surfaceHighest = Color(red: 0.200, green: 0.200, blue: 0.230)

        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.82)
        static let textTertiary = Color.white.opacity(0.68)

        static let primary = Color(red: 0.0, green: 0.478, blue: 1.0)          // #007AFF Apple System Blue
        /// primary 보다 밝고 개방적인 sky-blue — wideSelfie 전용 (#64B5F6 계열)
        static let primaryLight = Color(red: 0.392, green: 0.710, blue: 0.965) // #64B5F6
        static let tertiary = Color(red: 0.914, green: 0.702, blue: 1.0)       // #E9B3FF luminous violet
        static let accentCyan = Color(red: 0.39, green: 0.87, blue: 1.0)

        static let success = Color(red: 0.33, green: 0.86, blue: 0.53)
        static let warning = Color(red: 0.98, green: 0.82, blue: 0.30)
        static let danger = Color(red: 1.0, green: 0.42, blue: 0.42)

        static let glassOverlay = surface.opacity(0.70)
        static let cardOverlay = Color.white.opacity(0.08)
        static let cardOverlayStrong = Color.white.opacity(0.14)

        // Camera-specific — stitch AI camera assistant reference
        /// AI 분석 칩 테두리 (border-white/10)
        static let chipBorder = Color.white.opacity(0.10)
        /// 사이드 플로팅 버튼 배경 (surface-container-high/80)
        static let sideControlBg = surfaceHigh.opacity(0.80)
        /// 셔터 글로우 (primary/20)
        static let shutterGlow = primary.opacity(0.20)
    }

    enum Gradients {
        // Signature AI/magic gradient: Primary → Tertiary (blue-to-violet)
        static let hero = LinearGradient(
            colors: [Colors.primary, Colors.tertiary],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )

        static let cameraBackground = LinearGradient(
            colors: [Colors.surface, Color(red: 0.05, green: 0.20, blue: 0.28)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let activeDock = LinearGradient(
            colors: [Colors.primary, Colors.tertiary],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// 지도 하단 그라데이션 오버레이 — FloatingDockBar 진입 전환용
        static let mapOverlayBottom = LinearGradient(
            colors: [Colors.surface.opacity(0), Colors.surface.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Typography {
        static let heroTitle = Font.system(size: 30, weight: .black)
        static let sectionTitle = Font.system(size: 24, weight: .bold)
        static let cardTitle = Font.system(size: 20, weight: .bold)
        static let title = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 14, weight: .medium)
        static let bodyStrong = Font.system(size: 14, weight: .semibold)
        static let microLabel = Font.system(size: 11, weight: .semibold)
        static let technical = Font.system(size: 11, weight: .medium, design: .monospaced)
        /// AI 분석 칩 텍스트 — 11px bold uppercase tracking-widest (stitch ref)
        static let chipLabel = Font.system(size: 11, weight: .bold)
    }

    enum Radius {
        static let card: CGFloat = 16
        static let cardLarge: CGFloat = 28
        static let button: CGFloat = 22
        static let dock: CGFloat = 32
        static let capsule: CGFloat = 999
    }

    enum Spacing {
        static let xxxs: CGFloat = 4
        static let xxs: CGFloat = 8
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32

        // Floating dock bar clearance (bar 68 + elevation 14 + bottom padding 24 + buffer 10)
        static let dockTotalClearance: CGFloat = 116
    }

    enum Shadow {
        static let ambient = Color.black.opacity(0.28)
        static let elevated = Color.black.opacity(0.25)
    }
}
