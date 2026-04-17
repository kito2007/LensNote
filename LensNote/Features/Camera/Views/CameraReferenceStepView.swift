//
//  CameraReferenceStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/22/26.
//

import SwiftUI
import PhotosUI

/// 레퍼런스 사진 분석 단계.
enum ReferenceAnalysisStage: Int, CaseIterable, Equatable {
    case idle
    case extractingTone
    case extractingColor
    case generatingPreset
    case completed

    var title: String {
        switch self {
        case .idle: return ""
        case .extractingTone: return "톤 분석 중"
        case .extractingColor: return "컬러 추출 중"
        case .generatingPreset: return "프리셋 생성 중"
        case .completed: return "분석 완료"
        }
    }

    /// 현재 스테이지까지 완료된 단계들을 표시하기 위한 서수.
    var progressIndex: Int { rawValue }
}

struct CameraReferenceStepView: View {
    @Binding var referencePickerItem: PhotosPickerItem?
    let selectedReferenceImage: UIImage?
    let analysisStage: ReferenceAnalysisStage
    let generatedPreset: FilterPreset?
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                CameraBackButton(action: onBack)
                Spacer()
            }

            Text("레퍼런스 사진")
                .font(LensNoteTheme.Typography.sectionTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            Text("참고 사진을 업로드하면 톤·컬러를 분석해 촬영 프리셋을 제안해요.")
                .font(.system(size: 17))
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)

            PhotosPicker(selection: $referencePickerItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: LensNoteTheme.Spacing.xxs) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16, weight: .semibold))
                    Text(selectedReferenceImage == nil ? "사진 선택" : "다른 사진 선택")
                        .font(LensNoteTheme.Typography.bodyStrong)
                }
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(LensNoteTheme.Colors.cardOverlayStrong)
                .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(analysisStage != .idle && analysisStage != .completed)

            if let selectedReferenceImage {
                Image(uiImage: selectedReferenceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                            .stroke(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
                    )
            } else {
                emptyHint
            }

            // MARK: - Analysis progression / results
            if analysisStage != .idle {
                analysisCard
            }

            Spacer(minLength: 0)

            if analysisStage == .completed {
                confirmButton
            }
        }
        .padding(LensNoteTheme.Spacing.sm)
        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LensNoteTheme.Colors.surface)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: analysisStage)
    }

    // MARK: - Empty hint

    private var emptyHint: some View {
        VStack(spacing: LensNoteTheme.Spacing.xs) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)

            Text("원하는 톤의 사진을 고르면\nLensNote가 프리셋을 만들어요.")
                .font(LensNoteTheme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(LensNoteTheme.Colors.cardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
    }

    // MARK: - Analysis Card

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xs) {
            ForEach(ReferenceAnalysisStage.allCases.filter { $0 != .idle && $0 != .completed }, id: \.rawValue) { stage in
                stageRow(stage)
            }

            if analysisStage == .completed, let preset = generatedPreset {
                Divider()
                    .background(LensNoteTheme.Colors.chipBorder)
                    .padding(.vertical, 2)
                presetSummary(preset)
            }
        }
        .padding(LensNoteTheme.Spacing.sm)
        .background(LensNoteTheme.Colors.cardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                .stroke(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
        )
    }

    private func stageRow(_ stage: ReferenceAnalysisStage) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            stageIcon(for: stage)
                .frame(width: 20, height: 20)

            Text(stage.title)
                .font(LensNoteTheme.Typography.bodyStrong)
                .foregroundStyle(
                    stageTextColor(for: stage)
                )

            Spacer()
        }
    }

    @ViewBuilder
    private func stageIcon(for stage: ReferenceAnalysisStage) -> some View {
        if analysisStage.progressIndex > stage.progressIndex {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LensNoteTheme.Colors.success)
        } else if analysisStage == stage {
            ProgressView()
                .tint(LensNoteTheme.Colors.accentCyan)
                .controlSize(.small)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(LensNoteTheme.Colors.textTertiary.opacity(0.5))
        }
    }

    private func stageTextColor(for stage: ReferenceAnalysisStage) -> Color {
        if analysisStage.progressIndex > stage.progressIndex {
            return LensNoteTheme.Colors.textSecondary
        } else if analysisStage == stage {
            return LensNoteTheme.Colors.textPrimary
        } else {
            return LensNoteTheme.Colors.textTertiary
        }
    }

    // MARK: - Preset Summary

    private func presetSummary(_ preset: FilterPreset) -> some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxs) {
            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LensNoteTheme.Colors.accentCyan)
                Text(preset.name)
                    .font(LensNoteTheme.Typography.title)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            }

            VStack(spacing: 6) {
                presetBar(label: "노출", value: preset.exposure)
                presetBar(label: "대비", value: preset.contrast)
                presetBar(label: "채도", value: preset.saturation)
                presetBar(label: "온도", value: preset.temperature)
                presetBar(label: "비네트", value: preset.vignette)
            }
            .padding(.top, 4)
        }
    }

    private func presetBar(label: String, value: Double) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Text(label)
                .font(LensNoteTheme.Typography.microLabel)
                .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(LensNoteTheme.Colors.cardOverlayStrong)
                        .frame(height: 4)

                    // Center indicator
                    Rectangle()
                        .fill(LensNoteTheme.Colors.chipBorder)
                        .frame(width: 1, height: 8)
                        .position(x: trackWidth / 2, y: 2)

                    // Value bar from center
                    let normalized = max(-1, min(1, value))
                    let barWidth = abs(normalized) * trackWidth / 2
                    let startX = normalized >= 0 ? trackWidth / 2 : (trackWidth / 2 - barWidth)
                    Capsule()
                        .fill(LensNoteTheme.Colors.accentCyan)
                        .frame(width: barWidth, height: 4)
                        .offset(x: startX)
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            Text(formattedValue(value))
                .font(LensNoteTheme.Typography.technical)
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func formattedValue(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))"
    }

    // MARK: - Confirm CTA

    private var confirmButton: some View {
        Button(action: onConfirm) {
            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("이 톤으로 촬영 시작")
                    .font(LensNoteTheme.Typography.title)
            }
            .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(LensNoteTheme.Gradients.hero)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
            .shadow(color: LensNoteTheme.Shadow.elevated, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

private struct CameraReferenceStepPreviewWrapper: View {
    @State var referencePickerItem: PhotosPickerItem? = nil

    let selectedReferenceImage: UIImage?
    let analysisStage: ReferenceAnalysisStage
    let generatedPreset: FilterPreset?

    var body: some View {
        CameraReferenceStepView(
            referencePickerItem: $referencePickerItem,
            selectedReferenceImage: selectedReferenceImage,
            analysisStage: analysisStage,
            generatedPreset: generatedPreset,
            onBack: {},
            onConfirm: {}
        )
    }
}

#Preview("Empty") {
    CameraReferenceStepPreviewWrapper(
        selectedReferenceImage: nil,
        analysisStage: .idle,
        generatedPreset: nil
    )
}

#Preview("Analyzing") {
    CameraReferenceStepPreviewWrapper(
        selectedReferenceImage: UIImage(systemName: "photo"),
        analysisStage: .extractingColor,
        generatedPreset: nil
    )
}

#Preview("Completed") {
    CameraReferenceStepPreviewWrapper(
        selectedReferenceImage: UIImage(systemName: "photo.fill"),
        analysisStage: .completed,
        generatedPreset: FilterPreset(
            name: "Soft Mood",
            exposure: 0.08,
            contrast: 0.06,
            saturation: -0.12,
            temperature: 0.20,
            vignette: 0.18
        )
    )
}
