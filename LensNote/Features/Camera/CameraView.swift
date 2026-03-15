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
private struct CameraDesign {
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
                selectionStep
            case .photo:
                referenceStep
            case .text:
                conceptStep
            case .manual:
                manualStep
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

    private var selectionStep: some View {
        VStack(alignment: .leading, spacing: CameraDesign.sectionSpacing) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("LensNote Camera")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                Text("촬영 전 입력 방식을 선택하고 AI 어시스트를 시작하세요.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
            }

            VStack(spacing: CameraDesign.itemSpacing) {
                modeButton(
                    title: "레퍼런스 사진 분석",
                    subtitle: "사진 톤을 분석해 추천값을 생성",
                    tint: .blue
                ) {
                    step = .photo
                }

                modeButton(
                    title: "텍스트 컨셉 입력",
                    subtitle: "원하는 스타일 키워드로 시작",
                    tint: .cyan
                ) {
                    step = .text
                }

                modeButton(
                    title: "수동 설정",
                    subtitle: "필터 값을 직접 조정",
                    tint: .mint
                ) {
                    step = .manual
                }

                modeButton(
                    title: "카메라 바로 시작",
                    subtitle: "기본값으로 즉시 촬영",
                    tint: .white
                ) {
                    step = .camera
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(CameraDesign.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.12, blue: 0.19), Color(red: 0.05, green: 0.35, blue: 0.43)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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

    private var conceptStep: some View {
        VStack(alignment: .leading, spacing: CameraDesign.sectionSpacing) {
            HStack {
                backButton { step = .select }
                Spacer()
            }

            Text("컨셉 입력")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            TextField("예: 야경, 인물, 풍경", text: $conceptInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
                .foregroundStyle(.white)

            Button("카메라 시작") {
                viewModel.conceptText = conceptInput
                viewModel.applyConcept()
                step = .camera
            }
            .buttonStyle(PrimaryCameraButtonStyle())
            .disabled(conceptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(conceptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

            Spacer()
        }
        .padding(CameraDesign.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var manualStep: some View {
        VStack(alignment: .leading, spacing: CameraDesign.itemSpacing) {
            HStack {
                backButton { step = .select }
                Spacer()
            }

            Text("수동 필터 설정")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            manualSlider(title: "Exposure", value: $manualExposure)
            manualSlider(title: "Contrast", value: $manualContrast)
            manualSlider(title: "Saturation", value: $manualSaturation)
            manualSlider(title: "Temperature", value: $manualTemperature)
            manualSlider(title: "Vignette", value: $manualVignette, range: 0...1)

            Button("적용하고 카메라 시작") {
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
            }
            .buttonStyle(PrimaryCameraButtonStyle())
            .padding(.top, 8)

            Spacer()
        }
        .padding(CameraDesign.screenPadding)
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
                Text("구도: \(viewModel.guidanceMessage)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(2)
                // 점수와 촬영 가능 여부를 같이 보여줘서 현재 상태를 빠르게 이해하게 한다.
                Text(viewModel.readyToCapture ? "촬영 준비 완료 · score \(Int(viewModel.guidanceScore * 100))" : "구도 조정 중 · score \(Int(viewModel.guidanceScore * 100))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.readyToCapture ? .green : .yellow)
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

    private func manualSlider(title: String, value: Binding<Double>, range: ClosedRange<Double> = -1...1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }
            Slider(value: value, in: range)
                .tint(.cyan)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CameraDesign.cardRadius, style: .continuous))
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

private struct PrimaryCameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.41, blue: 0.98), Color(red: 0.08, green: 0.80, blue: 0.87)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: CameraDesign.buttonRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private struct SecondaryCameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: CameraDesign.buttonRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.black.opacity(0.48))
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.8 : 1)
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
