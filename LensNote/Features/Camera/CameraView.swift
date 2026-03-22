//
//  CameraView.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

/// 카메라 플로우 단계 상태.
private enum CameraInputMode: String {
    case select
    case photo
    case text
    case manual
    case camera
    case result
}

/// Camera 화면 공통 디자인 상수.
struct CameraDesign {
    static let screenPadding: CGFloat = 16
    static let cardRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 22
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 12
}

/// 카메라 탭 메인 화면.
/// 입력(레퍼런스/텍스트/수동) -> 촬영 -> 결과 저장의 플로우를 하나의 상태 머신(step)으로 관리한다.
struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    
    @State private var step: CameraInputMode = .select
    @State private var conceptInput: String = ""
    @State private var referencePickerItem: PhotosPickerItem?
    @State private var selectedReferenceImage: UIImage?
    @State private var capturedImage: UIImage?
    
    @State private var manualExposure: Double = 0.0
    @State private var manualContrast: Double = 0.0
    @State private var manualSaturation: Double = 0.0
    @State private var manualTemperature: Double = 0.0
    @State private var manualVignette: Double = 0.0
    
    @State private var isAnalyzing: Bool = false
    @State private var showGrid: Bool = true
    @State private var showSaveSuccess: Bool = false
    
    private let assistService: CameraAssistServiceProtocol = CoreMLCameraAssistService()
    
    init(viewModel: CameraViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            switch step {
            case .select:
                CameraSelectionStepView(
                    onSelectPhoto: { step = .photo},
                    onSelectText: {step = .text},
                    onSelectManual: {step = .manual},
                    onSelectCamera: {step = .camera}
                )
            case .photo:
                referenceStep
            case .text:
                CameraConceptStepView(
                    conceptInput: $conceptInput,
                    onBack: { step = .select },
                    onStartCamera: {
                        viewModel.conceptText = conceptInput
                        viewModel.applyConcept()
                        step = .camera
                    }
                )
            case .manual:
                CameraManualStepView(
                    onBack: {step = .select},
                    onStartCamera: {
                        viewModel.conceptText = "Manual"
                        viewModel.preset = FilterPreset(
                            name: "Manual",
                            exposure: manualExposure,
                            contrast: manualContrast,
                            saturation: manualSaturation,
                            temperature: manualTemperature,
                            vignette: manualVignette
                        )
                        step = .camera
                    },
                    manualExposure: $manualExposure,
                    manualContrast: $manualContrast,
                    manualSaturation: $manualSaturation,
                    manualTemperature: $manualTemperature,
                    manualVignette: $manualVignette)
                
            case .camera:
                liveCameraStep
            case .result:
                captureResultStep
            }
            
            if showSaveSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showSaveSuccess)
        .task(id: step) {
            // 카메라 단계에서만 AVCaptureSession을 실행하고, 나머지 단계에서는 중지한다.
            if step == .camera {
                await viewModel.startSessionIfNeeded()
            } else {
                viewModel.stopSession()
            }
        }
        .onChange(of: referencePickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadReferenceImage(from: newItem) }
        }
        .alert("카메라 권한 필요", isPresented: .constant(viewModel.isCameraAuthorized == false)) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("설정에서 카메라 접근을 허용해주세요.")
        }
    }
    
    private var referenceStep: some View {
        VStack(alignment: .leading, spacing: CameraDesign.sectionSpacing) {
            HStack {
                backButton { step = .select }
                Spacer()
            }
            
            Text("레퍼런스 사진")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("참고 사진을 업로드하면 임시 분석값으로 카메라 모드를 시작합니다.")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.82))
            
            PhotosPicker(selection: $referencePickerItem, matching: .images, photoLibrary: .shared()) {
                Label("사진 선택", systemImage: "photo")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: CameraDesign.buttonRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            
            if let selectedReferenceImage {
                Image(uiImage: selectedReferenceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
            }
            
            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("분석 중...")
                        .font(.headline)
                }
                .padding(12)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
            }
            
            Spacer()
        }
        .padding(CameraDesign.screenPadding)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private var liveCameraStep: some View {
        ZStack {
            // UIKit 기반 AVCaptureVideoPreviewLayer 래퍼 뷰
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()
            
            if let message = viewModel.cameraStatusMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(message)
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
            
            if let overlayState = viewModel.overlayState {
                // 목표 프레임과 현재 감지 프레임을 함께 그려
                // 사용자가 왜 현재 가이드를 받는지 바로 이해할 수 있게 한다.
                FramingGuideOverlay(state: overlayState)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 76)
            }
            
            VStack(spacing: CameraDesign.itemSpacing) {
                HStack {
                    backButton {
                        step = .select
                    }
                    
                    Spacer()
                    
                    Button {
                        showGrid.toggle()
                    } label: {
                        Image(systemName: showGrid ? "grid" : "grid.circle")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(HeaderIconButtonStyle())
                }
                .padding(.horizontal, CameraDesign.screenPadding)
                
                Spacer()
                
                CameraAssistPanel(
                    recommendation: assistService.recommendation(from: viewModel.preset, concept: viewModel.conceptText),
                    tips: assistService.compositionTips(concept: viewModel.conceptText, guidance: viewModel.guidanceMessage)
                )
                .padding(.horizontal, CameraDesign.screenPadding)
                
                captureBar
                    .padding(.horizontal, CameraDesign.screenPadding)
                    .padding(.bottom, CameraDesign.screenPadding)
            }
        }
    }
    
    private var captureResultStep: some View {
        VStack(spacing: CameraDesign.sectionSpacing) {
            HStack {
                backButton { step = .camera }
                Spacer()
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 44, weight: .medium))
                            Text("Captured Preview")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                }
                .frame(height: 320)
                .clipped()
            
            HStack(spacing: 12) {
                Button("다시 찍기") {
                    step = .camera
                }
                .buttonStyle(SecondaryCameraButtonStyle())
                
                Button("저장하기") {
                    guard let capturedImage else { return }
                    viewModel.saveCapturedImage(capturedImage)
                    showTransientSuccess()
                    step = .camera
                }
                .buttonStyle(PrimaryCameraButtonStyle())
            }
            
            if let saved = viewModel.lastSaved {
                Text("Saved: \(saved.id.uuidString.prefix(8))...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            if let err = viewModel.errorMessage {
                Text("Error: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(CameraDesign.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private var captureBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.conceptText.isEmpty ? "Standard Mode" : viewModel.conceptText)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let profileName = viewModel.overlayState?.profileName {
                    Text(profileName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Text("구도: \(viewModel.guidanceMessage)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(2)
                // 점수와 촬영 가능 여부를 같이 보여줘서 현재 상태를 빠르게 이해하게 한다.
                Text(viewModel.readyToCapture ? "촬영 준비 완료 · score \(Int(viewModel.guidanceScore * 100))" : "구도 조정 중 · score \(Int(viewModel.guidanceScore * 100))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.readyToCapture ? .green : .yellow)
                if let metrics = viewModel.overlayState?.metrics {
                    Text(debugSummary(metrics))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    // 촬영은 async로 수행하고 성공 시 결과 단계로 전환.
                    if let image = await viewModel.capturePhoto() {
                        await MainActor.run {
                            capturedImage = image
                            step = .result
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 2)
                        .frame(width: 60, height: 60)
                }
            }
            .disabled(viewModel.isCapturingPhoto)
            .opacity(viewModel.isCapturingPhoto ? 0.6 : 1)
            .accessibilityLabel("촬영")
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
    }
    
    private var successToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("사진이 저장되었습니다.")
                .font(.headline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private func modeButton(title: String, subtitle: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(tint == .white ? .black : .white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint == .white ? Color.white : tint.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
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
    
    private func loadReferenceImage(from item: PhotosPickerItem) async {
        // PhotosPickerItem -> Data -> UIImage 변환
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            selectedReferenceImage = image
        }
        analyzeReferencePhotoAndMove(image: image)
    }
    
    private func analyzeReferencePhotoAndMove(image: UIImage) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        Task { @MainActor in
            // UX용 짧은 지연 후 분석 결과를 반영
            try? await Task.sleep(nanoseconds: 900_000_000)
            viewModel.preset = assistService.analyzeReferenceImage(image)
            viewModel.conceptText = "Reference Mood"
            isAnalyzing = false
            step = .camera
        }
    }
    
    private func showTransientSuccess() {
        showSaveSuccess = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            showSaveSuccess = false
        }
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

/// 목표 구도 영역과 이동 방향을 프리뷰 위에 시각적으로 안내한다.
private struct FramingGuideOverlay: View {
    let state: GuidanceOverlayState
    
    var body: some View {
        GeometryReader { proxy in
            let targetRect = rect(from: state.targetRect, in: proxy.size)
            let detectedRect = state.detectedRect.map { rect(from: $0, in: proxy.size) }
            
            ZStack(alignment: .topLeading) {
                // 목표 구도 프레임.
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(state.readyToCapture ? Color.green : Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.5, dash: state.readyToCapture ? [] : [12, 8]))
                    .frame(width: targetRect.width, height: targetRect.height)
                    .position(x: targetRect.midX, y: targetRect.midY)
                
                if let detectedRect {
                    // 현재 감지된 피사체 프레임.
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
                    // 지금 가장 중요한 correction을 아이콘 하나로 강조한다.
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.yellow)
                        .position(arrowPosition(for: targetRect))
                }
                
                // 실기기 threshold 조정용 수치 패널.
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
        // 엔진은 0~1 정규화 좌표를 쓰므로 실제 프리뷰 크기로 환산한다.
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
