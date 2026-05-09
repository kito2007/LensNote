//
//  CameraConceptStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/21/26.
//
import SwiftUI

struct CameraConceptStepView: View {
    @Binding var conceptInput: String

    let onBack: () -> Void
    let onStartCamera: () -> Void

    private let suggestions = ["야경", "인물", "풍경", "무드", "빈티지", "따뜻한", "차가운"]

    private var trimmed: String {
        conceptInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isStartDisabled: Bool { trimmed.isEmpty }

    private var matchedPreset: FilterPreset {
        FilterPreset.forConcept(conceptInput)
    }

    private var hasMatch: Bool {
        matchedPreset != .standard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.sm) {
            HStack {
                CameraBackButton(action: onBack)
                Spacer()
            }

            headerBlock

            TextField("예: 야경 인물, 무드있게", text: $conceptInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(LensNoteTheme.Spacing.sm)
                .background(LensNoteTheme.Colors.cardOverlay)
                .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)

            suggestionChipsRow

            if !trimmed.isEmpty {
                previewCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)

            ctaButton
        }
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 배경은 Dynamic Island 뒤까지 채우고, 콘텐츠는 safe area 안에서 시작 (결함 1)
        .background(LensNoteTheme.Colors.surface, ignoresSafeAreaEdges: .all)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: matchedPreset)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: trimmed.isEmpty)
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xxxs) {
            Text("컨셉 입력")
                .font(LensNoteTheme.Typography.sectionTitle)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            Text("컨셉 키워드에 맞춰 필터 프리셋을 실시간으로 추천해요.")
                .font(.system(size: 15))
                .foregroundStyle(LensNoteTheme.Colors.textSecondary)
        }
    }

    // MARK: - Suggestion Chips

    private var suggestionChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        append(suggestion: suggestion)
                    } label: {
                        Text(suggestion)
                            .font(LensNoteTheme.Typography.chipLabel)
                            .foregroundStyle(
                                conceptInput.localizedCaseInsensitiveContains(suggestion)
                                    ? LensNoteTheme.Colors.accentCyan
                                    : LensNoteTheme.Colors.textPrimary
                            )
                            .padding(.horizontal, LensNoteTheme.Spacing.sm)
                            .padding(.vertical, LensNoteTheme.Spacing.xxs)
                            .background(LensNoteTheme.Colors.cardOverlayStrong)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func append(suggestion: String) {
        if trimmed.isEmpty {
            conceptInput = suggestion
        } else if conceptInput.localizedCaseInsensitiveContains(suggestion) {
            return
        } else {
            conceptInput += " \(suggestion)"
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xs) {
            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                Image(systemName: hasMatch ? "wand.and.stars" : "questionmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        hasMatch
                            ? LensNoteTheme.Colors.accentCyan
                            : LensNoteTheme.Colors.textTertiary
                    )
                Text(hasMatch ? "추천 프리셋" : "매칭되는 프리셋 없음")
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
                    .tracking(0.4)

                Spacer()

                if hasMatch {
                    Text(matchedPreset.name.uppercased())
                        .font(LensNoteTheme.Typography.chipLabel)
                        .foregroundStyle(LensNoteTheme.Colors.accentCyan)
                        .tracking(0.6)
                }
            }

            if hasMatch {
                PresetSummaryView(preset: matchedPreset, showsTitle: false)
            } else {
                Text("키워드를 바꾸면 LensNote가 톤 프리셋을 제안해요. 야경, 인물, 풍경, 무드, 빈티지 같은 단어를 시도해보세요.")
                    .font(LensNoteTheme.Typography.body)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
        }
        .padding(LensNoteTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LensNoteTheme.Colors.cardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous)
                .stroke(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
        )
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: onStartCamera) {
            HStack(spacing: LensNoteTheme.Spacing.xxs) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(ctaLabel)
                    .font(LensNoteTheme.Typography.title)
            }
            .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(LensNoteTheme.Gradients.hero)
            .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.button, style: .continuous))
            .shadow(color: LensNoteTheme.Shadow.elevated, radius: 12, y: 4)
            .opacity(isStartDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isStartDisabled)
    }

    private var ctaLabel: String {
        if isStartDisabled { return "카메라 시작" }
        if hasMatch { return "\(matchedPreset.name)으로 시작" }
        return "카메라 시작"
    }
}

private struct CameraConceptStepPreviewWrapper: View {
    @State private var conceptInput: String

    init(initial: String = "") {
        _conceptInput = State(initialValue: initial)
    }

    var body: some View {
        CameraConceptStepView(
            conceptInput: $conceptInput,
            onBack: {},
            onStartCamera: {}
        )
    }
}

#Preview("Empty") {
    CameraConceptStepPreviewWrapper()
}

#Preview("Matched") {
    CameraConceptStepPreviewWrapper(initial: "야경 인물")
}

#Preview("Unmatched") {
    CameraConceptStepPreviewWrapper(initial: "카페")
}
