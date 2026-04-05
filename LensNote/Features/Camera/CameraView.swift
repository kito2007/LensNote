//
//  CameraView.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI
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
    static let screenPadding: CGFloat = LensNoteTheme.Spacing.sm
    static let cardRadius: CGFloat = LensNoteTheme.Radius.card
    static let buttonRadius: CGFloat = LensNoteTheme.Radius.button
    static let sectionSpacing: CGFloat = LensNoteTheme.Spacing.sm
    static let itemSpacing: CGFloat = LensNoteTheme.Spacing.xs
}

/// 카메라 탭 메인 화면.
/// 입력(레퍼런스/텍스트/수동) -> 촬영 -> 결과 저장의 플로우를 하나의 상태 머신(step)으로 관리한다.
struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    /// 라이브 카메라 단계일 때 true — RootView에서 FloatingDockBar 숨김에 사용.
    @Binding var isLiveCamera: Bool

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
    
    init(viewModel: CameraViewModel, isLiveCamera: Binding<Bool> = .constant(false)) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _isLiveCamera = isLiveCamera
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
                CameraReferenceStepView(
                    referencePickerItem: $referencePickerItem,
                    selectedReferenceImage: selectedReferenceImage,
                    isAnalyzing: isAnalyzing,
                    onBack: {step = .select}
                )
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
                CameraLiveStepView(
                    session: viewModel.session,
                    cameraStatusMessage: viewModel.cameraStatusMessage,
                    overlayState: viewModel.overlayState,
                    showGrid: showGrid,
                    conceptText: viewModel.conceptText,
                    guidanceMessage: viewModel.guidanceMessage,
                    guidanceScore: viewModel.guidanceScore,
                    readyToCapture: viewModel.readyToCapture,
                    isCapturingPhoto: viewModel.isCapturingPhoto,
                    recommendation: assistService.recommendation(from: viewModel.preset, concept: viewModel.conceptText),
                    tips: assistService.compositionTips(concept: viewModel.conceptText, guidance: viewModel.guidanceMessage),
                    onBack: { step = .select },
                    onToggleGrid: { showGrid.toggle() },
                    onCapture: {
                        Task {
                            if let image = await viewModel.capturePhoto() {
                                await MainActor.run {
                                    capturedImage = image
                                    step = .result
                                }
                            }
                        }
                    }
                )
            case .result:
                CameraCaptureResultStepView(
                    capturedImage: capturedImage,
                    lastSaved: viewModel.lastSaved,
                    errorMessage: viewModel.errorMessage,
                    onBack: { step = .camera },
                    onRetake: { step = .camera },
                    onSave: {
                        guard let capturedImage else { return }
                        viewModel.saveCapturedImage(capturedImage)
                        showTransientSuccess()
                        step = .camera
                    }
                )
            }
            
            if showSaveSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if viewModel.hasLocationWarning {
                locationWarningToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showSaveSuccess)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.hasLocationWarning)
        .onChange(of: viewModel.hasLocationWarning) { _, isWarning in
            guard isWarning else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                viewModel.hasLocationWarning = false
            }
        }
        .onChange(of: step) { _, newStep in
            isLiveCamera = (newStep == .camera)
        }
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
    
    private var successToast: some View {
        HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LensNoteTheme.Colors.success)
            Text("사진이 저장되었습니다.")
                .font(LensNoteTheme.Typography.bodyStrong)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        }
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
        .padding(.vertical, LensNoteTheme.Spacing.xs)
        .background(
            ZStack {
                LensNoteTheme.Colors.surfaceHigh
                Color.clear.background(.ultraThinMaterial)
            }
        )
        .clipShape(Capsule())
        .shadow(color: LensNoteTheme.Shadow.ambient, radius: 12, y: 4)
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var locationWarningToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(LensNoteTheme.Colors.warning)
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text("위치 정보 없이 저장됐어요")
                    .font(LensNoteTheme.Typography.bodyStrong)
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                Text("이 사진은 지도에 표시되지 않습니다.")
                    .font(LensNoteTheme.Typography.microLabel)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
        .padding(.vertical, LensNoteTheme.Spacing.xs)
        .background(
            ZStack {
                LensNoteTheme.Colors.surfaceHigh
                Color.clear.background(.ultraThinMaterial)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        .shadow(color: LensNoteTheme.Shadow.ambient, radius: 12, y: 4)
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
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
