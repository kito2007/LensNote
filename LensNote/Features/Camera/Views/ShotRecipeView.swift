//
//  ShotRecipeView.swift
//  LensNote
//
//  레퍼런스 분석 완료 화면에서 PresetSummaryView 바로 아래에 위치하는 형제 카드.
//  ShotRecipe 도메인 타입은 별도 PR에서 정의 예정 — 여기서는 해당 타입이 존재한다고 가정한다.
//

import SwiftUI

// MARK: - ShotRecipeView

/// 레퍼런스 사진에서 역추출된 "촬영 동작 레시피"를 시각화하는 카드.
///
/// - 스타일 칩 + SF Symbol + 한국어 부연
/// - styleConfidence dots (●●●)
/// - cameraAngle / gazeDirection 행
/// - subjectCoverage 단방향 진행 바 (accentCyan)
/// - focalLength·aperture·iso·shutter·horizonTilt 단일 메타데이터 행
struct ShotRecipeView: View {
    let recipe: ShotRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            if isEmptyRecipe {
                emptyState
            } else {
                header
                styleChipSection
                if recipe.cameraAngle != nil || (recipe.gazeDirection != nil && recipe.gazeDirection != .unknown) {
                    angleAndGazeRow
                }
                if recipe.subjectCoverage != nil {
                    coverageBar
                }
                if hasMetadata {
                    metadataRow
                }
            }
        }
        .padding(LensNoteTheme.Spacing.md)
        .background(LensNoteTheme.Colors.cardOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous)
                .strokeBorder(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.cardLarge, style: .continuous))
    }

    // MARK: - Empty State

    private var isEmptyRecipe: Bool {
        recipe.detectedStyle == .unknown
            && recipe.focalLength35mm == nil
            && recipe.aperture == nil
            && recipe.iso == nil
            && recipe.shutterSpeed == nil
            && recipe.subjectCoverage == nil
            && recipe.cameraAngle == nil
            && recipe.gazeDirection == nil
    }

    private var emptyState: some View {
        HStack(spacing: LensNoteTheme.Spacing.xs) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            Text("분석 결과 없음 — 다른 사진을 시도해보세요")
                .font(LensNoteTheme.Typography.body)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, LensNoteTheme.Spacing.xxs)
    }

    // MARK: - Header: "SHOT RECIPE" microLabel + confidence dots

    private var header: some View {
        HStack(alignment: .center) {
            Text("SHOT RECIPE")
                .font(LensNoteTheme.Typography.chipLabel)
                .tracking(1.4)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)

            Spacer()

            confidenceDots
        }
    }

    private var confidenceDots: some View {
        HStack(spacing: 4) {
            // confidence 레이블
            Text(recipe.styleConfidence.displayLabel)
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(recipe.styleConfidence.dotColor)

            // 점 3개 — ● ● ●
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < recipe.styleConfidence.filledCount
                          ? recipe.styleConfidence.dotColor
                          : LensNoteTheme.Colors.textTertiary.opacity(0.30))
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - Style Chip Section

    private var styleChipSection: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxxs) {
            // 스타일 칩
            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                Image(systemName: recipe.detectedStyle.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(recipe.detectedStyle.accentColor)

                Text(recipe.detectedStyle.displayLabel)
                    .font(LensNoteTheme.Typography.chipLabel)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(recipe.detectedStyle.accentColor)
            }
            .padding(.horizontal, LensNoteTheme.Spacing.xs)
            .padding(.vertical, LensNoteTheme.Spacing.xxs)
            // 칩 배경: 해당 accent 색의 저채도 fill (stitch ref: glass pill)
            .background(recipe.detectedStyle.accentColor.opacity(0.12))
            .overlay(
                Capsule()
                    .strokeBorder(recipe.detectedStyle.accentColor.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())

            // 한 줄 부연 설명
            Text(recipe.detectedStyle.koreanDescription)
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                .padding(.leading, LensNoteTheme.Spacing.xxxs)
        }
    }

    // MARK: - Angle + Gaze Row

    private var angleAndGazeRow: some View {
        HStack(spacing: 0) {
            // cameraAngle
            if let angle = recipe.cameraAngle {
                angleCell(
                    symbol: angle.symbolName,
                    label: angle.displayLabel
                )
            }

            Spacer()

            // gazeDirection — unknown이면 숨김
            if let gaze = recipe.gazeDirection, gaze != .unknown {
                gazeCell(
                    symbol: gaze.symbolName,
                    label: gaze.displayLabel
                )
            }
        }
        .padding(.vertical, LensNoteTheme.Spacing.xxxs)
    }

    private func angleCell(symbol: String, label: String) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LensNoteTheme.Colors.primary)
            Text(label)
                .font(LensNoteTheme.Typography.chipLabel)
                .tracking(0.9)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
        }
    }

    private func gazeCell(symbol: String, label: String) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)
            Text(label)
                .font(LensNoteTheme.Typography.chipLabel)
                .tracking(0.9)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
        }
    }

    // MARK: - Subject Coverage Bar

    private var coverageBar: some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Text("SUBJECT")
                .font(LensNoteTheme.Typography.microLabel)
                .tracking(0.8)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                .frame(width: 52, alignment: .leading)

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                let coverage = max(0, min(1, recipe.subjectCoverage ?? 0))

                ZStack(alignment: .leading) {
                    // 트랙 배경
                    Capsule()
                        .fill(LensNoteTheme.Colors.cardOverlayStrong)
                        .frame(height: 4)

                    // 채워지는 바 — 단방향, accentCyan
                    Capsule()
                        .fill(LensNoteTheme.Colors.accentCyan)
                        .frame(width: trackWidth * coverage, height: 4)
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            // 퍼센트 텍스트
            if let coverage = recipe.subjectCoverage {
                Text("\(Int(coverage * 100))%")
                    .font(LensNoteTheme.Typography.technical)
                    .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    // MARK: - Metadata Row

    private var hasMetadata: Bool {
        recipe.focalLength35mm != nil
            || recipe.aperture != nil
            || recipe.iso != nil
            || recipe.shutterSpeed != nil
            || recipe.horizonTilt != nil
    }

    private var metadataRow: some View {
        Text(metadataString)
            .font(LensNoteTheme.Typography.technical)
            .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var metadataString: String {
        var parts: [String] = []

        if let focal = recipe.focalLength35mm {
            parts.append("\(Int(focal))mm")
        }
        if let aperture = recipe.aperture {
            parts.append("f/\(String(format: "%.1f", aperture))")
        }
        if let iso = recipe.iso {
            parts.append("ISO \(iso)")
        }
        if let shutter = recipe.shutterSpeed, shutter > 0 {
            let fraction = Int((1.0 / shutter).rounded())
            parts.append("1/\(fraction)s")
        }
        if let tilt = recipe.horizonTilt, abs(tilt) > 0.1 {
            let sign = tilt > 0 ? "+" : ""
            parts.append("\(sign)\(String(format: "%.1f", tilt))°")
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - ShotStyle Display Helpers

private extension ShotStyle {
    var displayLabel: String {
        switch self {
        case .aerialSelfie:   return "AERIAL SELFIE"
        case .mirrorSelfie:   return "MIRROR SELFIE"
        case .footShot:       return "FOOT SHOT"
        case .backView:       return "BACK VIEW"
        case .classicSelfie:  return "CLASSIC SELFIE"
        case .wideSelfie:     return "WIDE SELFIE"
        case .landscape:      return "LANDSCAPE"
        case .closeUp:        return "CLOSE-UP"
        case .unknown:        return "UNKNOWN"
        }
    }

    var koreanDescription: String {
        switch self {
        case .aerialSelfie:   return "위에서 내려다본 셀피"
        case .mirrorSelfie:   return "거울 앞 정면"
        case .footShot:       return "발끝 + 배경"
        case .backView:       return "뒷모습"
        case .classicSelfie:  return "정면 셀피"
        case .wideSelfie:     return "와이드 셀피 — 본인 + 배경"
        case .landscape:      return "풍경/배경 중심"
        case .closeUp:        return "근접/매크로"
        case .unknown:        return "스타일 미확정 — 더 선명한 레퍼런스를 골라보세요"
        }
    }

    /// SF Symbol name
    var symbolName: String {
        switch self {
        case .aerialSelfie:   return "airplane"
        case .mirrorSelfie:   return "rectangle.portrait.on.rectangle.portrait"
        case .footShot:       return "figure.walk"
        case .backView:       return "person.fill"
        case .classicSelfie:  return "person.crop.circle.fill"
        case .wideSelfie:     return "figure.arms.open"
        case .landscape:      return "mountain.2.fill"
        case .closeUp:        return "magnifyingglass.circle.fill"
        case .unknown:        return "questionmark"
        }
    }

    /// 스타일별 강조 색상.
    /// - aerialSelfie: accentCyan — 하늘·광활함
    /// - mirrorSelfie: accentCyan와 충돌을 피하기 위해 warning(gold) 사용 — 거울·내면 느낌
    /// - footShot: tertiary (luminous violet) — 재미있는 앵글
    /// - backView: warning (gold/amber) → mirrorSelfie가 warning을 쓰므로 danger(red-ish) 계열로 구분
    ///   실제 warm narrative 톤 유지 위해 warning 유지하고 mirrorSelfie는 다른 토큰 사용
    ///   최종 매핑: mirrorSelfie → accentCyan, backView → warning (서로 다른 톤)
    /// - classicSelfie: primary (Apple Blue) — 정통 인물 포트레이트
    /// - wideSelfie: primaryLight (sky-blue) — classicSelfie 변형, 넓고 개방적인 구도
    /// - landscape: success (green) — 자연 톤
    /// - closeUp: tertiary (violet) — 실험적/근접 느낌; footShot도 tertiary이나 displayLabel로 구분됨
    /// - unknown: textTertiary — 비활성 / 판별 불가
    var accentColor: Color {
        switch self {
        case .aerialSelfie:   return LensNoteTheme.Colors.accentCyan
        case .mirrorSelfie:   return LensNoteTheme.Colors.warning       // gold — 거울 반사 톤
        case .footShot:       return LensNoteTheme.Colors.tertiary
        case .backView:       return LensNoteTheme.Colors.danger         // warm red — 서정적 뒷모습 대비
        case .classicSelfie:  return LensNoteTheme.Colors.primary        // Apple Blue — 정통 인물
        case .wideSelfie:     return LensNoteTheme.Colors.primaryLight   // sky-blue — 광각/개방 구도
        case .landscape:      return LensNoteTheme.Colors.success        // green — 자연
        case .closeUp:        return LensNoteTheme.Colors.tertiary       // violet — 실험적
        case .unknown:        return LensNoteTheme.Colors.textTertiary
        }
    }
}

// MARK: - ShotStyleConfidence Display Helpers

private extension ShotStyleConfidence {
    var displayLabel: String {
        switch self {
        case .high:   return "HIGH"
        case .medium: return "MED"
        case .low:    return "LOW"
        }
    }

    var filledCount: Int {
        switch self {
        case .high:   return 3
        case .medium: return 2
        case .low:    return 1
        }
    }

    /// confidence 수준별 점 색상.
    /// - high: success (green) — 확실
    /// - medium: accentCyan — 중간
    /// - low: textTertiary — 낮음 (dim)
    var dotColor: Color {
        switch self {
        case .high:   return LensNoteTheme.Colors.success
        case .medium: return LensNoteTheme.Colors.accentCyan
        case .low:    return LensNoteTheme.Colors.textTertiary
        }
    }
}

// MARK: - CameraAngle Display Helpers

private extension CameraAngle {
    var displayLabel: String {
        switch self {
        case .highAngle: return "HIGH-ANGLE"
        case .eyeLevel:  return "EYE-LEVEL"
        case .lowAngle:  return "LOW-ANGLE"
        }
    }

    var symbolName: String {
        switch self {
        case .highAngle: return "arrow.up"
        case .eyeLevel:  return "eye"
        case .lowAngle:  return "arrow.down"
        }
    }
}

// MARK: - GazeDirection Display Helpers

private extension GazeDirection {
    var displayLabel: String {
        switch self {
        case .toCamera:        return "GAZE TO CAMERA"
        case .awayFromCamera:  return "GAZE AWAY"
        case .unknown:         return ""
        }
    }

    var symbolName: String {
        switch self {
        case .toCamera:        return "eye.fill"
        case .awayFromCamera:  return "arrow.up.right"
        case .unknown:         return "questionmark"
        }
    }
}

// MARK: - LensNoteTheme.Colors — cardOverlayStrong local fallback
// PresetSummaryView에서 동일하게 사용하는 토큰. LensNoteTheme에 이미 선언되어 있어 재선언 없이 참조.

// MARK: - Previews

#Preview("Aerial Selfie — High Confidence") {
    ScrollView {
        ShotRecipeView(
            recipe: ShotRecipe(
                focalLength35mm: 24,
                aperture: 1.8,
                iso: 200,
                shutterSpeed: 1.0 / 120.0,
                subjectCoverage: 0.65,
                subjectVerticalPosition: .top,
                subjectBoundingBox: nil,
                cameraAngle: .highAngle,
                gazeDirection: .toCamera,
                faceYaw: 0.05,
                facePitch: -0.3,
                horizonTilt: -2.0,
                detectedStyle: .aerialSelfie,
                styleConfidence: .high
            )
        )
        .padding(LensNoteTheme.Spacing.sm)
    }
    .background(LensNoteTheme.Colors.surface)
}

#Preview("Mirror Selfie — Medium Confidence") {
    ScrollView {
        ShotRecipeView(
            recipe: ShotRecipe(
                focalLength35mm: 35,
                aperture: 2.8,
                iso: 400,
                shutterSpeed: 1.0 / 60.0,
                subjectCoverage: 0.80,
                subjectVerticalPosition: .middle,
                subjectBoundingBox: nil,
                cameraAngle: .eyeLevel,
                gazeDirection: .toCamera,
                faceYaw: 0.0,
                facePitch: 0.0,
                horizonTilt: 0.5,
                detectedStyle: .mirrorSelfie,
                styleConfidence: .medium
            )
        )
        .padding(LensNoteTheme.Spacing.sm)
    }
    .background(LensNoteTheme.Colors.surface)
}

#Preview("Foot Shot — Low Confidence") {
    ScrollView {
        ShotRecipeView(
            recipe: ShotRecipe(
                focalLength35mm: 28,
                aperture: 4.0,
                iso: 100,
                shutterSpeed: 1.0 / 250.0,
                subjectCoverage: 0.30,
                subjectVerticalPosition: .bottom,
                subjectBoundingBox: nil,
                cameraAngle: .highAngle,
                gazeDirection: .awayFromCamera,
                faceYaw: nil,
                facePitch: nil,
                horizonTilt: -1.2,
                detectedStyle: .footShot,
                styleConfidence: .low
            )
        )
        .padding(LensNoteTheme.Spacing.sm)
    }
    .background(LensNoteTheme.Colors.surface)
}

#Preview("Back View — High Confidence") {
    ScrollView {
        ShotRecipeView(
            recipe: ShotRecipe(
                focalLength35mm: 50,
                aperture: 1.4,
                iso: 800,
                shutterSpeed: 1.0 / 500.0,
                subjectCoverage: 0.50,
                subjectVerticalPosition: .middle,
                subjectBoundingBox: nil,
                cameraAngle: .eyeLevel,
                gazeDirection: .awayFromCamera,
                faceYaw: nil,
                facePitch: nil,
                horizonTilt: 0.0,
                detectedStyle: .backView,
                styleConfidence: .high
            )
        )
        .padding(LensNoteTheme.Spacing.sm)
    }
    .background(LensNoteTheme.Colors.surface)
}

#Preview("Wide Selfie — MZ 광각 셀피") {
    ScrollView {
        ShotRecipeView(
            recipe: ShotRecipe(
                focalLength35mm: 24,
                aperture: 2.0,
                iso: 100,
                shutterSpeed: 1.0 / 120.0,
                subjectCoverage: 0.22,
                subjectVerticalPosition: .middle,
                subjectBoundingBox: CodableRect(CGRect(x: 0.3, y: 0.25, width: 0.38, height: 0.58)),
                cameraAngle: .eyeLevel,
                gazeDirection: .toCamera,
                faceYaw: 0.03,
                facePitch: nil,
                horizonTilt: nil,
                detectedStyle: .wideSelfie,
                styleConfidence: .medium
            )
        )
        .padding(LensNoteTheme.Spacing.sm)
    }
    .background(LensNoteTheme.Colors.surface)
}

#Preview("Unknown — 빈 케이스") {
    ScrollView {
        ShotRecipeView(
            recipe: ShotRecipe(
                focalLength35mm: nil,
                aperture: nil,
                iso: nil,
                shutterSpeed: nil,
                subjectCoverage: nil,
                subjectVerticalPosition: nil,
                subjectBoundingBox: nil,
                cameraAngle: nil,
                gazeDirection: nil,
                faceYaw: nil,
                facePitch: nil,
                horizonTilt: nil,
                detectedStyle: .unknown,
                styleConfidence: .low
            )
        )
        .padding(LensNoteTheme.Spacing.sm)
    }
    .background(LensNoteTheme.Colors.surface)
}
