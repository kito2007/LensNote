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

    let onBack: () -> Void
    let onToggleGrid: () -> Void
    let onCapture: () -> Void

    var body: some View {
        ZStack {
            CameraPreview(session: session)
                .ignoresSafeArea()

            if let cameraStatusMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(cameraStatusMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
                .padding(14)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
                .padding(.horizontal, CameraDesign.screenPadding)
            }

            if showGrid {
                GridOverlayView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if let overlayState {
                FramingGuideOverlay(state: overlayState)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 76)
            }

            VStack(spacing: CameraDesign.itemSpacing) {
                HStack {
                    backButton(action: onBack)

                    Spacer()

                    Button(action: onToggleGrid) {
                        Image(systemName: showGrid ? "grid" : "grid.circle")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(HeaderIconButtonStyle())
                }
                .padding(.horizontal, CameraDesign.screenPadding)

                Spacer()

                CameraAssistPanel(
                    recommendation: recommendation,
                    tips: tips
                )
                .padding(.horizontal, CameraDesign.screenPadding)

                captureBar
                    .padding(.horizontal, CameraDesign.screenPadding)
                    .padding(.bottom, CameraDesign.screenPadding)
            }
        }
    }

    private var captureBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(conceptText.isEmpty ? "Standard Mode" : conceptText)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let profileName = overlayState?.profileName {
                    Text(profileName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Text("구도: \(guidanceMessage)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(2)
                Text(readyToCapture ? "촬영 준비 완료 · score \(Int(guidanceScore * 100))" : "구도 조정 중 · score \(Int(guidanceScore * 100))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(readyToCapture ? .green : .yellow)
                if let metrics = overlayState?.metrics {
                    Text(debugSummary(metrics))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 2)
                        .frame(width: 60, height: 60)
                }
            }
            .disabled(isCapturingPhoto)
            .opacity(isCapturingPhoto ? 0.6 : 1)
            .accessibilityLabel("촬영")
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
    }

    private func debugSummary(_ metrics: GuidanceDebugMetrics) -> String {
        String(
            format: "x %.2f  y %.2f  size %.2f  roll %.2f  stab %.2f",
            metrics.xError,
            metrics.yError,
            metrics.sizeError,
            metrics.rollError,
            metrics.stabilityError
        )
    }
}

private func backButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: "chevron.left")
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.12))
            .clipShape(Circle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .accessibilityLabel("뒤로")
}

private struct FramingGuideOverlay: View {
    let state: GuidanceOverlayState

    var body: some View {
        GeometryReader { proxy in
            let targetRect = rect(from: state.targetRect, in: proxy.size)
            let detectedRect = state.detectedRect.map { rect(from: $0, in: proxy.size) }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(state.readyToCapture ? Color.green : Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.5, dash: state.readyToCapture ? [] : [12, 8]))
                    .frame(width: targetRect.width, height: targetRect.height)
                    .position(x: targetRect.midX, y: targetRect.midY)

                if let detectedRect {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.95), style: StrokeStyle(lineWidth: 2))
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
                        .foregroundStyle(Color.yellow)
                        .position(arrowPosition(for: targetRect))
                }

                metricsPanel
                    .position(x: proxy.size.width - 96, y: 48)
            }
        }
    }

    private var guideBadge: some View {
        Text(state.profileName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.48))
            .clipShape(Capsule())
    }

    private var detectedBadge: some View {
        Text("Live")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            metricRow("score", state.metrics.score)
            metricRow("x", state.metrics.xError)
            metricRow("y", state.metrics.yError)
            metricRow("size", state.metrics.sizeError)
            metricRow("roll", state.metrics.rollError)
            metricRow("stab", state.metrics.stabilityError)
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metricRow(_ label: String, _ value: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.white.opacity(0.55))
            Text(String(format: "%.2f", value))
        }
    }

    private var correctionSymbol: String? {
        switch state.correction {
        case .moveLeft:
            return "arrow.left.circle.fill"
        case .moveRight:
            return "arrow.right.circle.fill"
        case .moveUp, .adjustHeadroom:
            return "arrow.up.circle.fill"
        case .moveDown:
            return "arrow.down.circle.fill"
        case .moveCloser:
            return "plus.magnifyingglass"
        case .moveFarther:
            return "minus.magnifyingglass"
        case .levelHorizon:
            return "arrow.left.and.right.righttriangle.left.righttriangle.right.fill"
        case .holdSteady:
            return "hand.raised.fill"
        case .brightenScene:
            return "sun.max.fill"
        case .reduceHighlights:
            return "sun.min.fill"
        case .findSubject:
            return "viewfinder"
        case .none:
            return nil
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
        case .moveLeft:
            return CGPoint(x: rect.minX - 18, y: rect.midY)
        case .moveRight:
            return CGPoint(x: rect.maxX + 18, y: rect.midY)
        case .moveUp, .adjustHeadroom:
            return CGPoint(x: rect.midX, y: rect.minY - 18)
        case .moveDown:
            return CGPoint(x: rect.midX, y: rect.maxY + 18)
        case .moveCloser, .moveFarther, .levelHorizon, .holdSteady, .brightenScene, .reduceHighlights, .findSubject, .none:
            return CGPoint(x: rect.midX, y: rect.midY)
        }
    }
}

private struct GridOverlayView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                let w1 = width / 3
                let w2 = w1 * 2
                let h1 = height / 3
                let h2 = h1 * 2

                path.move(to: CGPoint(x: w1, y: 0))
                path.addLine(to: CGPoint(x: w1, y: height))
                path.move(to: CGPoint(x: w2, y: 0))
                path.addLine(to: CGPoint(x: w2, y: height))
                path.move(to: CGPoint(x: 0, y: h1))
                path.addLine(to: CGPoint(x: width, y: h1))
                path.move(to: CGPoint(x: 0, y: h2))
                path.addLine(to: CGPoint(x: width, y: h2))
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
        }
    }
}

private struct CameraAssistPanel: View {
    let recommendation: CameraRecommendation
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recommendation.title)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                AssistCell(title: "ISO", value: recommendation.iso)
                AssistCell(title: "셔터", value: recommendation.shutterSpeed)
            }
            HStack(spacing: 8) {
                AssistCell(title: "조리개", value: recommendation.aperture)
                AssistCell(title: "WB", value: recommendation.whiteBalance)
            }

            if let first = tips.first {
                Text("📐 \(first)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
    }
}

private struct AssistCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.footnote)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

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
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = self.layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return layer
        }
    }
}

private struct CameraLiveStepPreviewWrapper: View {
    @State private var showGrid: Bool

    let cameraStatusMessage: String?
    let overlayState: GuidanceOverlayState?
    let recommendation: CameraRecommendation
    let tips: [String]

    init(
        showGrid: Bool,
        cameraStatusMessage: String?,
        overlayState: GuidanceOverlayState?,
        recommendation: CameraRecommendation,
        tips: [String]
    ) {
        _showGrid = State(initialValue: showGrid)
        self.cameraStatusMessage = cameraStatusMessage
        self.overlayState = overlayState
        self.recommendation = recommendation
        self.tips = tips
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
        tips: ["조금 더 왼쪽으로", "배경 요소를 단순화"]
    )
}
