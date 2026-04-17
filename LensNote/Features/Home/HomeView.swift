//
//  HomeView.swift
//  LensNote
//

import SwiftUI

struct HomeView: View {
    let onUploadReference: () -> Void
    let onOpenCamera: () -> Void
    let onOpenMapGallery: () -> Void

    // TODO: 실제 유저 프로필 연동 시 ViewModel로 교체
    private let userName = "Julian"
    private let userLocation = "Oslo, Norway"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.lg) {
                    topBar
                    greetingSection
                    heroCard
                    quickShotCard
                    mapGalleryCard
                    recentSessionsSection
                }
                .padding(.horizontal, LensNoteTheme.Spacing.lg)
                .padding(.top, LensNoteTheme.Spacing.xl)
                .padding(.bottom, LensNoteTheme.Spacing.dockTotalClearance)
            }
            .background(LensNoteTheme.Colors.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Top Bar

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

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxxs) {
            Text(Date.now.formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                .tracking(0.8)

            Text("Hi, \(userName)")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            Label(userLocation, systemImage: "location.fill")
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        Button(action: onUploadReference) {
            ZStack(alignment: .topTrailing) {
                LensNoteTheme.Gradients.hero

                Image(systemName: "sparkles")
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.14))
                    .padding(.top, LensNoteTheme.Spacing.lg)
                    .padding(.trailing, LensNoteTheme.Spacing.md)

                VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.md) {
                    Text("AI POWERED")
                        .font(LensNoteTheme.Typography.microLabel)
                        .foregroundStyle(.white.opacity(0.86))
                        .tracking(0.6)
                        .padding(.horizontal, LensNoteTheme.Spacing.xs)
                        .padding(.vertical, LensNoteTheme.Spacing.xxs)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxs) {
                        Text("Match the\nVision")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(.white)

                        Text("레퍼런스 사진을 업로드하면 LensNote가 카메라 설정과 구도 방향의 시작점을 잡아줍니다.")
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
            .shadow(color: LensNoteTheme.Colors.primary.opacity(0.30), radius: 32, y: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Shot Card (vertical — stitch ref 준수)

    private var quickShotCard: some View {
        Button(action: onOpenCamera) {
            VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LensNoteTheme.Colors.primary.opacity(0.18))

                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LensNoteTheme.Colors.primary)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxxs) {
                    Text("Quick Shot")
                        .font(LensNoteTheme.Typography.cardTitle)
                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                    Text("Manual pro controls with instant metadata logging.")
                        .font(LensNoteTheme.Typography.body)
                        .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Open Camera")
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(LensNoteTheme.Colors.surfaceHighest)
                    .overlay(
                        Capsule()
                            .stroke(LensNoteTheme.Colors.primary.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .padding(.top, LensNoteTheme.Spacing.xxs)
            }
            .padding(LensNoteTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LensNoteTheme.Colors.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Map Gallery Card (Captured Moments preview)

    private var mapGalleryCard: some View {
        Button(action: onOpenMapGallery) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.11, blue: 0.18),
                        Color(red: 0.04, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle map watermark for context (grayscale feel)
                Image(systemName: "map.fill")
                    .font(.system(size: 160, weight: .ultraLight))
                    .foregroundStyle(LensNoteTheme.Colors.tertiary.opacity(0.10))
                    .rotationEffect(.degrees(-8))
                    .offset(x: 40, y: 10)

                // Top-left map chip
                VStack {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(LensNoteTheme.Colors.surface.opacity(0.80))
                            Image(systemName: "map.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(LensNoteTheme.Colors.tertiary)
                        }
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
                        )

                        Spacer()
                    }
                    Spacer()
                }
                .padding(LensNoteTheme.Spacing.md)

                // Bottom glass footer
                VStack(alignment: .leading, spacing: 6) {
                    Text("Captured Moments")
                        .font(LensNoteTheme.Typography.bodyStrong)
                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                    HStack(spacing: LensNoteTheme.Spacing.xxs) {
                        avatarStack

                        Text("128 PLACES")
                            .font(LensNoteTheme.Typography.microLabel)
                            .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                            .tracking(0.6)
                    }
                }
                .padding(LensNoteTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        LensNoteTheme.Colors.surface.opacity(0.55)
                        Color.clear.background(.ultraThinMaterial)
                    }
                }
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var avatarStack: some View {
        HStack(spacing: -6) {
            miniAvatar(LensNoteTheme.Colors.primary)
            miniAvatar(LensNoteTheme.Colors.tertiary)
            miniAvatar(LensNoteTheme.Colors.accentCyan)
        }
    }

    private func miniAvatar(_ color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.35))
            .overlay(
                Circle().stroke(LensNoteTheme.Colors.surface, lineWidth: 2)
            )
            .frame(width: 22, height: 22)
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                Text("Recent Sessions")
                    .font(LensNoteTheme.Typography.title)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                Spacer()

                Text("SEE ALL")
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.primary)
                    .tracking(0.6)
            }

            // TODO: 실제 세션 데이터 연동 시 SessionRepository로 교체
            VStack(spacing: LensNoteTheme.Spacing.xs) {
                ForEach(RecentSession.mockData) { session in
                    recentSessionRow(session)
                }
            }
        }
    }

    private func recentSessionRow(_ session: RecentSession) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xs) {
            sessionThumbnail(session.accentColor)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(session.gearLabel)
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.trailing.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(session.trailing.color(base: session.accentColor))
                    .tracking(0.4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
        }
        .padding(LensNoteTheme.Spacing.sm)
        .background(LensNoteTheme.Colors.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
    }

    private func sessionThumbnail(_ color: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [color.opacity(0.45), color.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }
}

// MARK: - Mock Data

private struct RecentSession: Identifiable {
    let id = UUID()
    let title: String
    let gearLabel: String
    let accentColor: Color
    let trailing: Trailing

    enum Trailing {
        case match(percent: Int)
        case timeAgo(String)

        var label: String {
            switch self {
            case .match(let percent): return "MATCH \(percent)%"
            case .timeAgo(let text): return text.uppercased()
            }
        }

        func color(base: Color) -> Color {
            switch self {
            case .match: return base
            case .timeAgo: return LensNoteTheme.Colors.textTertiary
            }
        }
    }

    static let mockData: [RecentSession] = [
        RecentSession(
            title: "Morning Fog in Nordmarka",
            gearLabel: "Fujifilm X-T4 · 35mm f/2.0",
            accentColor: LensNoteTheme.Colors.tertiary,
            trailing: .match(percent: 94)
        ),
        RecentSession(
            title: "Aker Brygge Nightscape",
            gearLabel: "Sony A7IV · 24mm f/1.4",
            accentColor: LensNoteTheme.Colors.accentCyan,
            trailing: .timeAgo("2h ago")
        ),
        RecentSession(
            title: "Golden Hour Rooftop",
            gearLabel: "Leica Q2 · 28mm f/1.7",
            accentColor: LensNoteTheme.Colors.primary,
            trailing: .match(percent: 72)
        ),
    ]
}

// MARK: - Preview

#Preview {
    HomeView(
        onUploadReference: {},
        onOpenCamera: {},
        onOpenMapGallery: {}
    )
}
