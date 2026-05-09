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
    case extractingShot
    case completed

    /// 진행 중일 때 표시되는 라벨 (예: "톤 분석 중")
    var activeTitle: String {
        switch self {
        case .idle: return ""
        case .extractingTone: return "톤 분석 중"
        case .extractingColor: return "컬러 추출 중"
        case .generatingPreset: return "프리셋 생성 중"
        case .extractingShot: return "샷 레시피 추출 중"
        case .completed: return "분석 완료"
        }
    }

    /// 완료된 단계에 표시되는 라벨 — "중" 없이 간결하게
    var completedTitle: String {
        switch self {
        case .idle: return ""
        case .extractingTone: return "톤 분석"
        case .extractingColor: return "컬러 추출"
        case .generatingPreset: return "프리셋 생성"
        case .extractingShot: return "샷 레시피 추출"
        case .completed: return "분석 완료"
        }
    }

    /// 하위 호환용 기존 접근자 — 외부에서 `.title` 을 참조하는 곳이 없으면 삭제 가능
    var title: String { activeTitle }

    /// 현재 스테이지까지 완료된 단계들을 표시하기 위한 서수.
    var progressIndex: Int { rawValue }
}

struct CameraReferenceStepView: View {
    @Binding var referencePickerItem: PhotosPickerItem?
    let selectedReferenceImage: UIImage?
    let analysisStage: ReferenceAnalysisStage
    let generatedPreset: FilterPreset?
    let generatedRecipe: ShotRecipe?
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
                // 헤더 — CameraBackButton + 제목 + 부제
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
                    // scaledToFit: 세로 인물 사진도 짤림 없이 비율 보존.
                    // maxHeight 300 캡: 초광각 가로 사진이 너무 작아지지 않도록 제한.
                    Image(uiImage: selectedReferenceImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 300)
                        .background(LensNoteTheme.Colors.cardOverlay)
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
            }
            .padding(.horizontal, LensNoteTheme.Spacing.sm)
            // safe area top — Dynamic Island 아래에서 시작하도록 확보
            .padding(.top, LensNoteTheme.Spacing.sm)
            .padding(.bottom, LensNoteTheme.Spacing.xxs)
        }
        // CTA를 ScrollView 외부 하단에 항상 고정.
        // 이 sub-step에서는 RootView의 FloatingDockBar가 숨겨지므로
        // dockTotalClearance 추가 패딩은 불필요.
        // .bottom safeAreaInset이 시스템 home indicator를 처리하고,
        // xs 패딩은 home indicator 위 여백을 확보한다.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if analysisStage == .completed {
                confirmButton
                    .padding(.horizontal, LensNoteTheme.Spacing.sm)
                    .padding(.top, LensNoteTheme.Spacing.xs)
                    .padding(.bottom, LensNoteTheme.Spacing.xs)
                    .background(
                        LensNoteTheme.Colors.surface
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
        }
        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 배경은 Dynamic Island 뒤까지 채우고, 콘텐츠는 safe area 안에서 시작 (결함 1)
        .background(LensNoteTheme.Colors.surface, ignoresSafeAreaEdges: .all)
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
                PresetSummaryView(preset: preset)
            }

            if analysisStage == .completed, let recipe = generatedRecipe {
                Divider()
                    .background(LensNoteTheme.Colors.chipBorder)
                    .padding(.vertical, 2)
                ShotRecipeView(recipe: recipe)
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
        let isCompleted = analysisStage.progressIndex > stage.progressIndex
        let label = isCompleted ? stage.completedTitle : stage.activeTitle
        return HStack(spacing: LensNoteTheme.Spacing.xxs) {
            stageIcon(for: stage)
                .frame(width: 20, height: 20)

            Text(label)
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

    // MARK: - Confirm CTA

    /// 마지막 글자가 한글 음절일 때 받침 여부를 판별해 "으로" / "로" 를 반환한다.
    /// 유니코드 한글 음절: 0xAC00 ~ 0xD7A3. 각 음절 = (초성 * 21 + 중성) * 28 + 종성.
    /// 종성 인덱스가 0이면 받침 없음 → "로", 그 외 → "으로".
    private func josa(after word: String) -> String {
        guard let last = word.unicodeScalars.last,
              last.value >= 0xAC00, last.value <= 0xD7A3 else { return "으로" }
        return ((last.value - 0xAC00) % 28 != 0) ? "으로" : "로"
    }

    private var confirmButtonLabel: String {
        guard let recipe = generatedRecipe, recipe.detectedStyle != .unknown else {
            return "이 톤으로 촬영 시작"
        }
        let styleKorean: String
        switch recipe.detectedStyle {
        case .aerialSelfie:   styleKorean = "항공샷"
        case .mirrorSelfie:   styleKorean = "거울샷"
        case .footShot:       styleKorean = "발끝샷"
        case .backView:       styleKorean = "뒷모습"
        case .classicSelfie:  styleKorean = "정면 셀피"
        case .wideSelfie:     styleKorean = "와이드 셀피"
        case .landscape:      styleKorean = "풍경"
        case .closeUp:        styleKorean = "근접샷"
        case .unknown:        styleKorean = ""
        }
        return "이 톤 + \(styleKorean)\(josa(after: styleKorean)) 촬영 시작"
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(confirmButtonLabel)
                    .font(LensNoteTheme.Typography.title)
                    .animation(.spring(response: 0.38, dampingFraction: 0.88), value: confirmButtonLabel)
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
    var generatedRecipe: ShotRecipe? = nil

    var body: some View {
        CameraReferenceStepView(
            referencePickerItem: $referencePickerItem,
            selectedReferenceImage: selectedReferenceImage,
            analysisStage: analysisStage,
            generatedPreset: generatedPreset,
            generatedRecipe: generatedRecipe,
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
