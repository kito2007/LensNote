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
                    capturedMomentsSection
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

    // MARK: - Quick Shot Card

    private var quickShotCard: some View {
        Button(action: onOpenCamera) {
            HStack(spacing: LensNoteTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LensNoteTheme.Colors.primary.opacity(0.18))

                    Image(systemName: "camera.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LensNoteTheme.Colors.primary)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Shot")
                        .font(LensNoteTheme.Typography.cardTitle)
                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                    Text("즉시 촬영 흐름으로 이동")
                        .font(LensNoteTheme.Typography.body)
                        .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                }

                Spacer()

                Text("Open Camera")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LensNoteTheme.Colors.primary)
                    .padding(.horizontal, LensNoteTheme.Spacing.sm)
                    .padding(.vertical, 8)
                    .background(LensNoteTheme.Colors.primary.opacity(0.14))
                    .clipShape(Capsule())
            }
            .padding(LensNoteTheme.Spacing.lg)
            .background(LensNoteTheme.Colors.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Captured Moments

    private var capturedMomentsSection: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            Text("Captured Moments")
                .font(LensNoteTheme.Typography.title)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            // TODO: 실제 사진 데이터 연동 시 PhotoRepository로 교체
            capturedMomentCard
        }
    }

    private var capturedMomentCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.18, blue: 0.35),
                    Color(red: 0.05, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text("아직 캡처된 사진이 없습니다")
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)

                Text("카메라로 첫 촬영을 시작해보세요")
                    .font(LensNoteTheme.Typography.body)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
            .padding(LensNoteTheme.Spacing.lg)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
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
            VStack(spacing: 0) {
                ForEach(RecentSession.mockData) { session in
                    recentSessionRow(session)

                    if session.id != RecentSession.mockData.last?.id {
                        Divider()
                            .background(LensNoteTheme.Colors.surfaceHighest)
                            .padding(.leading, 68)
                    }
                }
            }
            .background(LensNoteTheme.Colors.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        }
    }

    private func recentSessionRow(_ session: RecentSession) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(session.accentColor.opacity(0.20))

                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(session.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(session.dateLabel)
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("\(session.matchPercent)%")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(session.accentColor)

                Text("MATCH")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                    .tracking(0.4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(session.accentColor.opacity(0.14))
            .clipShape(Capsule())
        }
        .padding(.horizontal, LensNoteTheme.Spacing.lg)
        .padding(.vertical, LensNoteTheme.Spacing.sm)
    }
}

// MARK: - Mock Data

private struct RecentSession: Identifiable {
    let id = UUID()
    let title: String
    let dateLabel: String
    let matchPercent: Int
    let accentColor: Color

    static let mockData: [RecentSession] = [
        RecentSession(title: "Morning Fog in Norway", dateLabel: "오늘 · 4장", matchPercent: 87, accentColor: LensNoteTheme.Colors.primary),
        RecentSession(title: "Åker Brygge Nightscape", dateLabel: "3월 29일 · 9장", matchPercent: 95, accentColor: LensNoteTheme.Colors.tertiary),
        RecentSession(title: "Golden Hour Rooftop", dateLabel: "3월 27일 · 6장", matchPercent: 72, accentColor: LensNoteTheme.Colors.accentCyan),
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
