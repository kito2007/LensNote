//
//  CameraLiveStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/28/26.
//

import SwiftUI
import AVFoundation

struct CameraLiveStepView: View {
    let session: AVCaptureSession
    let cameraStatusMessage: String?
    let overlayState: GuidanceOverlayState?
    let showGrid: Bool
    let conceptText: String
    let guidanceMessage: String
    let guidanceScore: Double
    let readyToCapture: Bool
    let isCapturingPhoto: Bool
    let recommendation: CameraRecommendation
    let tips: [String]
    /// AI 장면 분류 레이블 (예: "PORTRAIT"). conceptText가 비면 이 값이 FILTER 칩에 표시된다.
    var sceneLabel: String = "STANDARD"
    /// CoreML 종합 추론 점수 (0~1). guidanceScore와 함께 SCORE 칩에 표시된다.
    var inferenceScore: Double = 0.0
    /// 화면에 실제로 노출할 구도 힌트 문구. nil이면 배너를 숨긴다.
    var activeGuidanceHint: String? = nil

    let onBack: () -> Void
    let onToggleGrid: () -> Void
    let onCapture: () -> Void

    var body: some View {
        ZStack {
            // MARK: - Camera feed
            CameraPreview(session: session)
                .ignoresSafeArea()

            // Glass overlay for depth — stitch ref: from-black/20 via-transparent to-black/40
            LinearGradient(
                colors: [
                    Color.black.opacity(0.20),
                    Color.clear,
                    Color.black.opacity(0.40)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // MARK: - Camera status error
            if let cameraStatusMessage {
                cameraStatusBanner(cameraStatusMessage)
            }

            // MARK: - Composition guides
            if showGrid {
                GridOverlayView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // AI dynamic alignment circle — stitch ref: dashed border, primary color
            AIDynamicAlignmentOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if let overlayState {
                FramingGuideOverlay(state: overlayState)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 76)
            }

            // MARK: - UI layers
            VStack(spacing: 0) {
                // Top bar — back + grid toggle
                topBar
                    .padding(.horizontal, LensNoteTheme.Spacing.sm)
                    .padding(.top, LensNoteTheme.Spacing.xxs)

                Spacer()
            }

            // MARK: - AI Analysis Chips (left-aligned, below top bar)
            VStack(spacing: 0) {
                aiAnalysisChips
                    .padding(.top, 64)
                    .padding(.leading, LensNoteTheme.Spacing.sm)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // MARK: - Side floating controls
            sideControls

            // MARK: - Bottom capture controls + guidance banner
            VStack(spacing: LensNoteTheme.Spacing.xs) {
                Spacer()
                if let activeGuidanceHint {
                    guidanceBanner(activeGuidanceHint)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .opacity
                        ))
                }
                bottomCaptureBar
                    .padding(.horizontal, LensNoteTheme.Spacing.xl)
                    .padding(.bottom, LensNoteTheme.Spacing.md)
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.88), value: activeGuidanceHint)
        }
    }

    // MARK: - Guidance Banner

    private func guidanceBanner(_ text: String) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)
            Text(text)
                .font(LensNoteTheme.Typography.bodyStrong)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
        .padding(.vertical, LensNoteTheme.Spacing.xs)
        .background(LensNoteTheme.Colors.surface.opacity(0.55))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
        )
        .shadow(color: LensNoteTheme.Shadow.elevated, radius: 16, y: 6)
        .padding(.horizontal, LensNoteTheme.Spacing.xl)
        .accessibilityLabel("구도 안내")
        .accessibilityValue(text)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(LensNoteTheme.Colors.sideControlBg)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Spacer()

            Button(action: onToggleGrid) {
                Image(systemName: showGrid ? "grid" : "grid.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(LensNoteTheme.Colors.sideControlBg)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - AI Analysis Chips

    private var aiAnalysisChips: some View {
        VStack(alignment: .leading, spacing: LensNoteTheme.Spacing.xs) {
            // Chip 1: Filter/Concept — AI 장면 분류 레이블, conceptText가 있으면 우선 표시
            analysisChip(
                icon: "paintpalette.fill",
                iconColor: LensNoteTheme.Colors.tertiary,
                label: "FILTER",
                value: conceptText.isEmpty ? sceneLabel : conceptText.uppercased()
            )

            // Chip 2: Camera settings — primary icon
            analysisChip(
                icon: "camera.aperture",
                iconColor: LensNoteTheme.Colors.primary,
                label: "ISO",
                value: recommendation.iso.uppercased()
            )

            // Chip 3: Guidance score — CoreML inferenceScore 우선, fallback은 Vision guidanceScore
            analysisChip(
                icon: "scope",
                iconColor: LensNoteTheme.Colors.accentCyan,
                label: "SCORE",
                value: "\(Int(max(inferenceScore, guidanceScore) * 100))%"
            )
        }
    }

    private func analysisChip(
        icon: String,
        iconColor: Color,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)

            Text("\(label): \(value)")
                .font(LensNoteTheme.Typography.chipLabel)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        }
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
        .padding(.vertical, LensNoteTheme.Spacing.xxs)
        .background(LensNoteTheme.Colors.surface.opacity(0.40))
        .background(.ultraThinMaterial.opacity(0.6))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
        )
    }

    // MARK: - Side Floating Controls

    private var sideControls: some View {
        HStack {
            // Left: Map shortcut
            VStack {
                Spacer()
                sideButton(icon: "map")
                    .padding(.bottom, 120)
            }
            .padding(.leading, LensNoteTheme.Spacing.xxs)

            Spacer()

            // Right: Photo library shortcut
            VStack {
                Spacer()
                sideButton(icon: "photo.on.rectangle")
                    .padding(.bottom, 120)
            }
            .padding(.trailing, LensNoteTheme.Spacing.xxs)
        }
    }

    private func sideButton(icon: String) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                .frame(width: 56, height: 56)
                .background(LensNoteTheme.Colors.sideControlBg)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: LensNoteTheme.Shadow.elevated, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Capture Bar

    private var bottomCaptureBar: some View {
        HStack(alignment: .center) {
            // Left: Reference thumbnail
            referenceThumb

            Spacer()

            // Center: Shutter button
            shutterButton

            Spacer()

            // Right: AI magic button
            aiMagicButton
        }
    }

    private var referenceThumb: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .stroke(LensNoteTheme.Colors.primary, lineWidth: 2)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "photo.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(LensNoteTheme.Colors.textSecondary)
                )

            Text("REF")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(LensNoteTheme.Colors.primary)
                .clipShape(Capsule())
                .offset(x: 4, y: -4)
        }
    }

    private var shutterButton: some View {
        ZStack {
            // Glow behind
            Circle()
                .fill(LensNoteTheme.Colors.shutterGlow)
                .frame(width: 96, height: 96)
                .blur(radius: 24)

            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                }
            }
            .buttonStyle(ShutterButtonStyle())
            .disabled(isCapturingPhoto)
            .opacity(isCapturingPhoto ? 0.6 : 1)
            .accessibilityLabel("촬영")
        }
    }

    private var aiMagicButton: some View {
        Button(action: {}) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                .frame(width: 64, height: 64)
                .background(LensNoteTheme.Gradients.hero)
                .clipShape(Circle())
                .shadow(color: LensNoteTheme.Shadow.elevated, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera Status Banner

    private func cameraStatusBanner(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LensNoteTheme.Colors.warning)
            Text(message)
                .font(LensNoteTheme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        }
        .padding(14)
        .background(LensNoteTheme.Colors.surface.opacity(0.75))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
    }
}

// MARK: - Shutter Button Style

private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - AI Dynamic Alignment Overlay

private struct AIDynamicAlignmentOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius: CGFloat = 96

            ZStack {
                // Dashed circle — stitch ref: composition-guide, 1.5px dashed, primary/40
                Circle()
                    .strokeBorder(
                        LensNoteTheme.Colors.primary.opacity(0.40),
                        style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Center dot
                Circle()
                    .fill(LensNoteTheme.Colors.primary)
                    .frame(width: 4, height: 4)
                    .position(center)

                // Horizontal alignment line — stitch ref: tertiary/30
                Rectangle()
                    .fill(LensNoteTheme.Colors.tertiary.opacity(0.30))
                    .frame(width: proxy.size.width, height: 1)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.45)
            }
        }
    }
}

// MARK: - Grid Overlay

private struct GridOverlayView: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            Path { path in
                let w1 = w / 3, w2 = w1 * 2
                let h1 = h / 3, h2 = h1 * 2

                path.move(to: CGPoint(x: w1, y: 0))
                path.addLine(to: CGPoint(x: w1, y: h))
                path.move(to: CGPoint(x: w2, y: 0))
                path.addLine(to: CGPoint(x: w2, y: h))
                path.move(to: CGPoint(x: 0, y: h1))
                path.addLine(to: CGPoint(x: w, y: h1))
                path.move(to: CGPoint(x: 0, y: h2))
                path.addLine(to: CGPoint(x: w, y: h2))
            }
            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        }
    }
}

// MARK: - Framing Guide Overlay

private struct FramingGuideOverlay: View {
    let state: GuidanceOverlayState

    var body: some View {
        GeometryReader { proxy in
            let targetRect = rect(from: state.targetRect, in: proxy.size)
            let detectedRect = state.detectedRect.map { rect(from: $0, in: proxy.size) }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        state.readyToCapture ? LensNoteTheme.Colors.success : Color.white.opacity(0.92),
                        style: StrokeStyle(lineWidth: 2.5, dash: state.readyToCapture ? [] : [12, 8])
                    )
                    .frame(width: targetRect.width, height: targetRect.height)
                    .position(x: targetRect.midX, y: targetRect.midY)

                if let detectedRect {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(LensNoteTheme.Colors.accentCyan.opacity(0.95), style: StrokeStyle(lineWidth: 2))
                        .frame(width: detectedRect.width, height: detectedRect.height)
                        .position(x: detectedRect.midX, y: detectedRect.midY)
                }

                guideBadge
                    .position(x: targetRect.minX + 86, y: max(20, targetRect.minY - 26))

                if let detectedRect {
                    detectedBadge
                        .position(x: detectedRect.minX + 78, y: detectedRect.maxY + 18)
                }

                if !state.readyToCapture, let symbol = correctionSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LensNoteTheme.Colors.warning)
                        .position(arrowPosition(for: targetRect))
                }
            }
        }
    }

    private var guideBadge: some View {
        Text(state.profileName)
            .font(LensNoteTheme.Typography.microLabel)
            .foregroundStyle(LensNoteTheme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LensNoteTheme.Colors.surface.opacity(0.48))
            .background(.ultraThinMaterial.opacity(0.5))
            .clipShape(Capsule())
    }

    private var detectedBadge: some View {
        Text("Live")
            .font(.caption2.weight(.bold))
            .foregroundStyle(LensNoteTheme.Colors.accentCyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(LensNoteTheme.Colors.surface.opacity(0.55))
            .clipShape(Capsule())
    }

    private var correctionSymbol: String? {
        switch state.correction {
        case .moveLeft: return "arrow.left.circle.fill"
        case .moveRight: return "arrow.right.circle.fill"
        case .moveUp, .adjustHeadroom: return "arrow.up.circle.fill"
        case .moveDown: return "arrow.down.circle.fill"
        case .moveCloser: return "plus.magnifyingglass"
        case .moveFarther: return "minus.magnifyingglass"
        case .levelHorizon: return "arrow.left.and.right.righttriangle.left.righttriangle.right.fill"
        case .holdSteady: return "hand.raised.fill"
        case .brightenScene: return "sun.max.fill"
        case .reduceHighlights: return "sun.min.fill"
        case .findSubject: return "viewfinder"
        case .none: return nil
        }
    }

    private func rect(from normalizedRect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalizedRect.minX * size.width,
            y: normalizedRect.minY * size.height,
            width: normalizedRect.width * size.width,
            height: normalizedRect.height * size.height
        )
    }

    private func arrowPosition(for rect: CGRect) -> CGPoint {
        switch state.correction {
        case .moveLeft: return CGPoint(x: rect.minX - 18, y: rect.midY)
        case .moveRight: return CGPoint(x: rect.maxX + 18, y: rect.midY)
        case .moveUp, .adjustHeadroom: return CGPoint(x: rect.midX, y: rect.minY - 18)
        case .moveDown: return CGPoint(x: rect.midX, y: rect.maxY + 18)
        case .moveCloser, .moveFarther, .levelHorizon, .holdSteady,
             .brightenScene, .reduceHighlights, .findSubject, .none:
            return CGPoint(x: rect.midX, y: rect.midY)
        }
    }
}

// MARK: - Camera Preview

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewView else { return }
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = self.layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return layer
        }
    }
}

// MARK: - Previews

private struct CameraLiveStepPreviewWrapper: View {
    @State private var showGrid: Bool

    let cameraStatusMessage: String?
    let overlayState: GuidanceOverlayState?
    let recommendation: CameraRecommendation
    let tips: [String]
    let activeGuidanceHint: String?

    init(
        showGrid: Bool,
        cameraStatusMessage: String?,
        overlayState: GuidanceOverlayState?,
        recommendation: CameraRecommendation,
        tips: [String],
        activeGuidanceHint: String? = nil
    ) {
        _showGrid = State(initialValue: showGrid)
        self.cameraStatusMessage = cameraStatusMessage
        self.overlayState = overlayState
        self.recommendation = recommendation
        self.tips = tips
        self.activeGuidanceHint = activeGuidanceHint
    }

    var body: some View {
        CameraLiveStepView(
            session: AVCaptureSession(),
            cameraStatusMessage: cameraStatusMessage,
            overlayState: overlayState,
            showGrid: showGrid,
            conceptText: "야경 인물",
            guidanceMessage: overlayState?.correction.message ?? "피사체를 교차점에 맞춰보세요.",
            guidanceScore: overlayState?.metrics.score ?? 0.78,
            readyToCapture: overlayState?.readyToCapture ?? false,
            isCapturingPhoto: false,
            recommendation: recommendation,
            tips: tips,
            activeGuidanceHint: activeGuidanceHint,
            onBack: {},
            onToggleGrid: { showGrid.toggle() },
            onCapture: {}
        )
    }
}

#Preview("Default") {
    CameraLiveStepPreviewWrapper(
        showGrid: true,
        cameraStatusMessage: nil,
        overlayState: nil,
        recommendation: CameraRecommendation(
            title: "Night Assist",
            iso: "ISO 800-1600",
            shutterSpeed: "1/60s",
            aperture: "f/2.0",
            whiteBalance: "3600K"
        ),
        tips: ["피사체를 교차점에 배치", "수평을 조금 더 맞춰보세요."]
    )
}

#Preview("Guided") {
    CameraLiveStepPreviewWrapper(
        showGrid: true,
        cameraStatusMessage: nil,
        overlayState: GuidanceOverlayState(
            targetRect: CGRect(x: 0.18, y: 0.18, width: 0.56, height: 0.56),
            detectedRect: CGRect(x: 0.28, y: 0.22, width: 0.42, height: 0.46),
            correction: .moveLeft,
            readyToCapture: false,
            profileName: "Portrait Half",
            metrics: GuidanceDebugMetrics(
                score: 0.74,
                xError: 0.12,
                yError: 0.05,
                sizeError: 0.08,
                rollError: 0.03,
                stabilityError: 0.02
            )
        ),
        recommendation: CameraRecommendation(
            title: "Portrait Assist",
            iso: "ISO 200",
            shutterSpeed: "1/125s",
            aperture: "f/2.8",
            whiteBalance: "AWB"
        ),
        tips: ["조금 더 왼쪽으로", "배경 요소를 단순화"],
        activeGuidanceHint: "피사체를 왼쪽으로 이동해보세요."
    )
}
