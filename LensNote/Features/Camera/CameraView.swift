//
//  CameraView.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI
import PhotosUI
import UIKit

/// 카메라 플로우 단계 상태. Req 12 — 진입 즉시 라이브 뷰(`camera`), 촬영 후 결과(`result`)만 남긴다.
/// 레퍼런스/컨셉/수동 설정은 라이브 뷰 위 시트(`CameraSetupSheet`)로 전환됐다.
private enum CameraInputMode: String {
    case camera
    case result
}

/// 라이브 뷰에서 인라인으로 여는 셋업 시트 종류 (Req 12).
private enum CameraSetupSheet: String, Identifiable {
    case reference
    case concept
    case manual
    var id: String { rawValue }
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
    /// 풀스크린 라이브 뷰에서 홈으로 복귀(dock이 없으므로 탭 전환 경로 제공) (Req 12).
    private let onExit: () -> Void
    /// 결과 카드의 "지도에서 보기" — 저장된 PhotoItem id를 넘겨 지도 탭으로 이동 + 해당 핀 선택 (Req 2.2).
    private let onNavigateToMap: (UUID) -> Void
    /// 라이브 뷰 사이드 지도 버튼 — 지도 탭으로 전환(핀 선택 없음) (Req 3.1).
    private let onOpenMap: () -> Void

    @State private var step: CameraInputMode = .camera
    @State private var activeSetupSheet: CameraSetupSheet? = nil
    /// 갤러리 사이드 버튼으로 직접 띄우는 사진 피커 표시 여부 (Req 3.2).
    @State private var showGalleryPicker: Bool = false
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

    private let assistService: CameraAssistServiceProtocol = CoreMLCameraAssistService()
    
    init(
        viewModel: CameraViewModel,
        onExit: @escaping () -> Void = {},
        onNavigateToMap: @escaping (UUID) -> Void = { _ in },
        onOpenMap: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onExit = onExit
        self.onNavigateToMap = onNavigateToMap
        self.onOpenMap = onOpenMap
    }
    
    var body: some View {
        ZStack {
            switch step {
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
                    onExit: onExit,
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
                    },
                    onTapReference: { activeSetupSheet = .reference },
                    onTapConcept: { activeSetupSheet = .concept },
                    onTapManual: { activeSetupSheet = .manual },
                    onMapTap: onOpenMap,
                    onGalleryTap: { showGalleryPicker = true }
                )
            case .result:
                CameraCaptureResultStepView(
                    capturedImage: capturedImage,
                    result: viewModel.captureResult,
                    errorMessage: viewModel.errorMessage,
                    onBack: { viewModel.clearCaptureResult(); step = .camera },
                    onRetake: { viewModel.clearCaptureResult(); step = .camera },
                    onSave: {
                        guard let capturedImage else { return }
                        // 저장 성공 시 captureResult가 세팅되어 결과 카드로 전환된다(머무름).
                        viewModel.saveCapturedImage(capturedImage)
                    },
                    onNewShot: { viewModel.clearCaptureResult(); step = .camera },
                    onViewOnMap: {
                        guard let id = viewModel.captureResult?.photoID else { return }
                        onNavigateToMap(id)
                    }
                )
            }
            
            if viewModel.hasLocationWarning {
                locationWarningToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.hasLocationWarning)
        .onChange(of: viewModel.hasLocationWarning) { _, isWarning in
            guard isWarning else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                viewModel.hasLocationWarning = false
            }
        }
        .task(id: step) {
            // 라이브 뷰에서만 AVCaptureSession을 실행하고, 결과 단계에서는 중지한다.
            if step == .camera {
                await viewModel.startSessionIfNeeded()
            } else {
                viewModel.stopSession()
            }
        }
        .onChange(of: referencePickerItem) { _, newItem in
            guard let newItem else { return }
            // 갤러리 사이드 버튼으로 고른 경우(시트 미오픈) 레퍼런스 시트를 열어 분석을 보여준다 (Req 3.3).
            if activeSetupSheet == nil { activeSetupSheet = .reference }
            Task { await loadReferenceImage(from: newItem) }
        }
        // Req 3.2 — 갤러리 사이드 버튼: 시스템 사진 피커(PHPicker)를 직접 표시. 취소 시 라이브 뷰 유지(Req 3.4).
        .photosPicker(isPresented: $showGalleryPicker, selection: $referencePickerItem, matching: .images)
        .sheet(item: $activeSetupSheet) { sheet in
            setupSheet(sheet)
        }
        .alert("카메라 권한 필요", isPresented: .constant(viewModel.isCameraAuthorized == false)) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("설정에서 카메라 접근을 허용해주세요.")
        }
    }

    /// 라이브 뷰 위에 인라인으로 띄우는 셋업 시트. 적용/취소 후 시트를 닫고 라이브 뷰로 돌아온다(Req 12).
    @ViewBuilder
    private func setupSheet(_ sheet: CameraSetupSheet) -> some View {
        switch sheet {
        case .reference:
            CameraReferenceStepView(
                referencePickerItem: $referencePickerItem,
                selectedReferenceImage: selectedReferenceImage,
                analysisStage: referenceAnalysisStage,
                generatedPreset: referenceGeneratedPreset,
                generatedRecipe: referenceGeneratedRecipe,
                onBack: { resetReferenceFlow(); activeSetupSheet = nil },
                onConfirm: {
                    guard let preset = referenceGeneratedPreset else { return }
                    viewModel.preset = preset
                    viewModel.conceptText = "Reference Mood"
                    // Req 1 — 레퍼런스 ShotRecipe를 VM에 전달해 라이브 코칭 활성화.
                    viewModel.setReferenceRecipe(referenceGeneratedRecipe)
                    activeSetupSheet = nil
                }
            )
        case .concept:
            CameraConceptStepView(
                conceptInput: $conceptInput,
                onBack: { activeSetupSheet = nil },
                onStartCamera: {
                    viewModel.conceptText = conceptInput
                    viewModel.applyConcept()
                    // 컨셉 적용 — 레퍼런스 코칭 비활성화.
                    viewModel.setReferenceRecipe(nil)
                    activeSetupSheet = nil
                }
            )
        case .manual:
            CameraManualStepView(
                onBack: { activeSetupSheet = nil },
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
                    // 수동 적용 — 레퍼런스 코칭 비활성화.
                    viewModel.setReferenceRecipe(nil)
                    activeSetupSheet = nil
                },
                manualExposure: $manualExposure,
                manualContrast: $manualContrast,
                manualSaturation: $manualSaturation,
                manualTemperature: $manualTemperature,
                manualVignette: $manualVignette
            )
        }
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
}
