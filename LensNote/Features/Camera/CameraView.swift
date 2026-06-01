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
    /// selection 진입점 이외의 카메라 sub-step에서 true — RootView FloatingDockBar 숨김에 사용.
    @Binding var hidesFloatingDock: Bool

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
    
    @State private var referenceAnalysisStage: ReferenceAnalysisStage = .idle
    @State private var referenceGeneratedPreset: FilterPreset? = nil
    @State private var referenceImageData: Data? = nil
    @State private var referenceGeneratedRecipe: ShotRecipe? = nil
    @State private var showGrid: Bool = true
    @State private var showSaveSuccess: Bool = false
    
    private let assistService: CameraAssistServiceProtocol = CoreMLCameraAssistService()
    
    init(viewModel: CameraViewModel, hidesFloatingDock: Binding<Bool> = .constant(false)) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _hidesFloatingDock = hidesFloatingDock
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
                    analysisStage: referenceAnalysisStage,
                    generatedPreset: referenceGeneratedPreset,
                    generatedRecipe: referenceGeneratedRecipe,
                    onBack: { resetReferenceFlow(); step = .select },
                    onConfirm: {
                        guard let preset = referenceGeneratedPreset else { return }
                        viewModel.preset = preset
                        viewModel.conceptText = "Reference Mood"
                        // Req 1 — 레퍼런스 ShotRecipe를 VM에 전달해 라이브 코칭 활성화.
                        viewModel.setReferenceRecipe(referenceGeneratedRecipe)
                        step = .camera
                    }
                )
            case .text:
                CameraConceptStepView(
                    conceptInput: $conceptInput,
                    onBack: { step = .select },
                    onStartCamera: {
                        viewModel.conceptText = conceptInput
                        viewModel.applyConcept()
                        // 컨셉 경로 진입 — 레퍼런스 코칭 비활성화.
                        viewModel.setReferenceRecipe(nil)
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
                        // 수동 경로 진입 — 레퍼런스 코칭 비활성화.
                        viewModel.setReferenceRecipe(nil)
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
                    sceneLabel: viewModel.sceneLabel,
                    inferenceScore: viewModel.inferenceScore,
                    activeGuidanceHint: viewModel.activeGuidanceHint,
                    referenceImage: selectedReferenceImage,
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
            // selection은 dock 유지, 그 외 모든 sub-step에서 dock 숨김
            hidesFloatingDock = (newStep != .select)
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
            referenceImageData = data
        }
        analyzeReferencePhotoAndMove(image: image, data: data)
    }

    private func analyzeReferencePhotoAndMove(image: UIImage, data: Data) {
        guard referenceAnalysisStage == .idle || referenceAnalysisStage == .completed else { return }
        referenceGeneratedPreset = nil
        referenceGeneratedRecipe = nil
        referenceAnalysisStage = .extractingTone

        Task { @MainActor in
            // 단계 1: 톤 분석
            try? await Task.sleep(nanoseconds: 650_000_000)
            referenceAnalysisStage = .extractingColor

            // 단계 2: 컬러 추출
            try? await Task.sleep(nanoseconds: 650_000_000)
            referenceAnalysisStage = .generatingPreset

            // 단계 3: 프리셋 분석 (동기, 가벼움)
            let preset = assistService.analyzeReferenceImage(image)
            try? await Task.sleep(nanoseconds: 500_000_000)
            referenceGeneratedPreset = preset

            // 단계 4: 샷 레시피 추출 — 실제 Vision/DeepLabV3 분석, 백그라운드에서 실행
            referenceAnalysisStage = .extractingShot
            let recipe = await Task.detached(priority: .userInitiated) {
                await ShotRecipeAnalyzer().analyze(imageData: data)
            }.value

            await MainActor.run {
                referenceGeneratedRecipe = recipe
                referenceAnalysisStage = .completed
            }
        }
    }

    private func resetReferenceFlow() {
        referenceAnalysisStage = .idle
        referenceGeneratedPreset = nil
        referenceGeneratedRecipe = nil
        referenceImageData = nil
        selectedReferenceImage = nil
        referencePickerItem = nil
        // Req 1 — 레퍼런스 해제 시 라이브 코칭도 비활성화.
        viewModel.setReferenceRecipe(nil)
    }
    
    private func showTransientSuccess() {
        showSaveSuccess = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            showSaveSuccess = false
        }
    }
}
