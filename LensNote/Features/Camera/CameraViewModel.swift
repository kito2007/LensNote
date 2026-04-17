//
//  CameraViewModel.swift
//  LensNote
//
//  Created by 박태영 on 1/1/26.
//

// LensNote/Features/Camera/CameraViewModel.swift

import Foundation
import Combine
import AVFoundation
import UIKit

struct FilterPreset: Equatable {
    let name: String
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let temperature: Double
    let vignette: Double
}

extension FilterPreset {
    static let standard = FilterPreset(name: "Standard", exposure: 0, contrast: 0, saturation: 0, temperature: 0, vignette: 0)

    /// 컨셉 문자열에 기반한 필터 프리셋을 결정한다.
    /// 뷰 미리보기와 뷰모델 적용이 동일한 룰을 공유하도록 단일 소스로 유지.
    static func forConcept(_ text: String) -> FilterPreset {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return .standard }

        if keyword.contains("무드") || keyword.contains("시네마") || keyword.contains("cinematic") {
            return FilterPreset(name: "Cinematic", exposure: -0.1, contrast: 0.25, saturation: -0.05, temperature: -0.05, vignette: 0.4)
        }
        if keyword.contains("빈티지") || keyword.contains("필름") || keyword.contains("vintage") {
            return FilterPreset(name: "Vintage", exposure: 0.05, contrast: -0.1, saturation: -0.15, temperature: 0.15, vignette: 0.35)
        }
        if keyword.contains("야경") || keyword.contains("밤") || keyword.contains("night") {
            return FilterPreset(name: "Night Mood", exposure: -0.15, contrast: 0.30, saturation: -0.10, temperature: -0.10, vignette: 0.45)
        }
        if keyword.contains("인물") || keyword.contains("portrait") {
            return FilterPreset(name: "Portrait", exposure: 0.05, contrast: 0.08, saturation: 0.12, temperature: 0.12, vignette: 0.15)
        }
        if keyword.contains("풍경") || keyword.contains("landscape") {
            return FilterPreset(name: "Landscape", exposure: 0.02, contrast: 0.18, saturation: 0.20, temperature: -0.02, vignette: 0.10)
        }
        if keyword.contains("따뜻") || keyword.contains("warm") {
            return FilterPreset(name: "Warm", exposure: 0.1, contrast: 0.1, saturation: 0.1, temperature: 0.2, vignette: 0.2)
        }
        if keyword.contains("차가") || keyword.contains("cool") {
            return FilterPreset(name: "Cool", exposure: 0.0, contrast: 0.1, saturation: 0.05, temperature: -0.2, vignette: 0.15)
        }
        return .standard
    }
}

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    private let savePhotoUseCase: SavePhotoUseCase
    private let locationProvider: LocationProvider

    @Published var lastSaved: PhotoItem? = nil
    @Published var errorMessage: String? = nil

    @Published var conceptText: String = ""
    @Published var preset: FilterPreset? = nil
    @Published var guidanceMessage: String = "컨셉을 입력하면 구도 안내를 시작해요."
    /// 현재 프레임이 목표 구도에 얼마나 가까운지 표시하는 점수.
    @Published var guidanceScore: Double = 0.0
    /// 지금 바로 촬영해도 되는지 여부.
    @Published var readyToCapture: Bool = false
    /// 프리뷰 위에 그릴 타겟 프레임과 보정 방향 상태.
    @Published var overlayState: GuidanceOverlayState? = nil
    @Published var isCameraAuthorized: Bool? = nil
    @Published var isCapturingPhoto: Bool = false
    @Published var cameraStatusMessage: String? = nil
    /// 위치 정보 없이 사진이 저장됐을 때 true — 토스트 표시 후 false로 리셋된다.
    @Published var hasLocationWarning: Bool = false

    // MARK: - CoreML AI 추론 결과 (RealTimeInferenceEngine)
    /// AI가 감지한 장면 유형 레이블 (예: "PORTRAIT", "LANDSCAPE").
    @Published var sceneLabel: String = "STANDARD"
    /// AI 종합 추론 점수 (0~1).
    @Published var inferenceScore: Double = 0.0
    /// AI가 감지한 피사체 바운딩 박스 (정규화 좌표 0~1).
    @Published var coreMLSubjectBox: CGRect? = nil
    /// AI 기반 구도 힌트 문구 (원본, 디바운스 전).
    @Published var coreMLGuidanceHint: String? = nil
    /// UI에 실제로 노출되는 최종 구도 힌트. CoreML 힌트(디바운스 통과) > Vision guidanceMessage 순으로 선택.
    /// 힌트가 없으면 nil — UI에서 배너를 숨긴다.
    @Published private(set) var activeGuidanceHint: String? = nil

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
    private let sampleBufferQueue = DispatchQueue(label: "CameraSampleBufferQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    // 카메라 프레임 -> 구도 가이드 결과를 만드는 엔진
    private nonisolated(unsafe) let guidanceEngine = CompositionGuidanceEngine()
    // CoreML 실시간 AI 추론 엔진 (MobileNetV2 + DeepLabV3)
    private nonisolated(unsafe) let inferenceEngine = RealTimeInferenceEngine()
    // CoreMotion에서 기기 자세를 받아오는 제공자.
    private nonisolated(unsafe) let devicePoseProvider: DevicePoseProviding
    // 모델 학습/평가를 위한 프레임-가이드 샘플 기록기(JSONL)
    private let guidanceDatasetRecorder = GuidanceDatasetRecorder()
    private nonisolated(unsafe) var photoCaptureContinuation: CheckedContinuation<UIImage?, Never>?
    private var isSessionConfigured = false
    private var isRunning = false
    // 디바운스 후보 문구와 시작 시각
    private var pendingGuidanceMessage: String?
    private var pendingGuidanceSince = Date.distantPast
    // 마지막으로 실제 UI에 반영한 문구와 시각(쿨다운 판단용)
    private var lastGuidanceMessage: String = ""
    private var lastGuidanceAppliedAt = Date.distantPast

    // 가이드 UX 안정화 파라미터
    private let guidanceDebounceInterval: TimeInterval = 0.5
    private let repeatedGuidanceCooldown: TimeInterval = 1.4
    private let minimumGuidanceConfidence: Double = 0.42

    // CoreML 힌트 안정화 상태
    private var pendingCoreMLHint: String? = nil
    private var pendingCoreMLHintSince = Date.distantPast
    private var activeHintAppliedAt = Date.distantPast
    /// 같은 CoreML 힌트가 이 시간 이상 지속되어야 UI에 노출한다 (0.5초 추론 간격 기준 ≈ 2프레임).
    private let coreMLHintStabilityThreshold: TimeInterval = 0.9
    /// 한 번 표시된 힌트는 이 시간 동안은 숨기지 않는다 — 깜빡임 방지.
    private let coreMLHintMinDisplayDuration: TimeInterval = 1.6

    init(
        savePhotoUseCase: SavePhotoUseCase,
        devicePoseProvider: DevicePoseProviding? = nil,
        locationProvider: LocationProvider? = nil
    ) {
        self.savePhotoUseCase = savePhotoUseCase
        self.devicePoseProvider = devicePoseProvider ?? DevicePoseProvider()
        self.locationProvider = locationProvider ?? LocationProvider()
        super.init()
    }

    func applyConcept() {
        preset = FilterPreset.forConcept(conceptText)
        // 사용자가 입력한 컨셉을 엔진의 씬 힌트로 전달
        guidanceEngine.updateSceneHint(from: conceptText)
    }

    func startSessionIfNeeded() async {
        guard !isRunning else { return }

        let granted = await requestCameraAccess()
        isCameraAuthorized = granted
        guard granted else {
            guidanceMessage = "카메라 권한이 필요해요."
            cameraStatusMessage = "카메라 권한이 꺼져 있어요. 설정에서 권한을 허용해주세요."
            return
        }
        cameraStatusMessage = nil
        // 카메라 재진입 시에도 현재 컨셉으로 힌트 재동기화
        guidanceEngine.updateSceneHint(from: conceptText)
        // 세션과 함께 기기 자세 측정 및 위치 업데이트도 시작한다.
        devicePoseProvider.start()
        locationProvider.start()

        await configureSessionIfNeeded()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor in
                self.isRunning = false
                // 세션 종료 시 미확정 후보 문구 초기화
                self.pendingGuidanceMessage = nil
                // 세션이 멈추면 촬영 준비 상태도 초기화한다.
                self.readyToCapture = false
                self.overlayState = nil
            }
        }
        // 프레임 분석과 함께 쓰던 motion 업데이트도 중지한다.
        devicePoseProvider.stop()
        // 카메라 세션 종료 시 위치 업데이트도 중지한다.
        locationProvider.stop()
    }

    func mockCaptureAndSave() {
        do {
            let item = try savePhotoUseCase.execute(
                imagePath: "mock/path.jpg",
                coordinate: nil
            )
            lastSaved = item
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func capturePhoto() async -> UIImage? {
        guard isCameraAuthorized == true else { return nil }
        guard !isCapturingPhoto else { return nil }
        guard isSessionConfigured, isRunning else { return nil }
        guard let connection = photoOutput.connection(with: .video), connection.isEnabled else {
            errorMessage = "카메라 연결이 준비되지 않았어요. 잠시 후 다시 시도해주세요."
            return nil
        }

        isCapturingPhoto = true
        return await withCheckedContinuation { continuation in
            photoCaptureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                switch photoOutput.maxPhotoQualityPrioritization {
                case .quality:
                    settings.photoQualityPrioritization = .quality
                case .balanced:
                    settings.photoQualityPrioritization = .balanced
                case .speed:
                    settings.photoQualityPrioritization = .speed
                @unknown default:
                    settings.photoQualityPrioritization = .balanced
                }
            }
            settings.flashMode = .off

            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    /// 촬영된 이미지를 저장한다.
    /// coordinate 파라미터가 nil이면 LocationProvider의 최신 좌표를 자동으로 사용한다.
    /// 위치 정보를 전혀 구할 수 없으면 위치 없이 저장하고 hasLocationWarning을 true로 설정한다.
    func saveCapturedImage(_ image: UIImage, coordinate: GeoCoordinate? = nil) {
        let resolvedCoordinate = coordinate ?? locationProvider.latestCoordinate
        do {
            let filePath = try persistImageToDocuments(image)
            let saved = try savePhotoUseCase.execute(imagePath: filePath, coordinate: resolvedCoordinate)
            lastSaved = saved
            errorMessage = nil
            if resolvedCoordinate == nil {
                hasLocationWarning = true
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func configureSessionIfNeeded() async {
        guard !isSessionConfigured else { return }

        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                let candidateDevices: [AVCaptureDevice?] = [
                    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                    AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                    AVCaptureDevice.default(for: .video)
                ]
                if let device = candidateDevices.compactMap({ $0 }).first,
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    Task { @MainActor in
                        self.cameraStatusMessage = "카메라 입력을 구성할 수 없어요. 기기/권한 상태를 확인해주세요."
                    }
                }

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)

                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                } else {
                    Task { @MainActor in
                        self.cameraStatusMessage = "비디오 출력을 구성할 수 없어요."
                    }
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                } else {
                    Task { @MainActor in
                        self.cameraStatusMessage = "사진 출력을 구성할 수 없어요."
                    }
                }

                if let connection = self.videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                }

                if let photoConnection = self.photoOutput.connection(with: .video) {
                    photoConnection.videoOrientation = .portrait
                }

                self.session.commitConfiguration()
                self.isSessionConfigured = true
                continuation.resume()
            }
        }
    }

    private func persistImageToDocuments(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "CameraViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "이미지 인코딩 실패"])
        }
        let fileName = "photo_\(UUID().uuidString).jpg"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileURL = (documents ?? FileManager.default.temporaryDirectory).appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // 현재 프레임 시점의 기기 자세를 함께 읽어온다.
        let devicePose = devicePoseProvider.latestPose
        // Vision 기반 feature와 motion 정보를 합쳐 최종 가이드를 만든다.
        guard let result = guidanceEngine.analyze(sampleBuffer: sampleBuffer, devicePose: devicePose) else { return }
        Task { @MainActor [weak self] in
            // 고빈도 프레임 이벤트에서 바로 UI 반영하지 않고 안정화 로직 통과
            guard let self else { return }
            let accepted = self.applyGuidanceResult(result)
            self.guidanceDatasetRecorder.record(result: result, concept: self.conceptText, acceptedForUI: accepted)
        }

        // CoreML 실시간 AI 추론 (스케줄러 스로틀링 내장 — 모델 로드 실패 시 nil 반환)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if let inferenceOutput = inferenceEngine.analyze(pixelBuffer: pixelBuffer) {
            Task { @MainActor [weak self] in
                self?.applyInferenceOutput(inferenceOutput)
            }
        }
    }
}

private extension CameraViewModel {
    /// CoreML AI 추론 결과를 Published 프로퍼티에 반영한다.
    /// 기존 Vision 기반 guidanceMessage/overlayState는 건드리지 않는다.
    @MainActor
    func applyInferenceOutput(_ output: AIInferenceOutput) {
        sceneLabel = output.sceneLabel
        inferenceScore = output.inferenceScore
        coreMLSubjectBox = output.subjectBoundingBox
        coreMLGuidanceHint = output.guidanceHint
        updateActiveGuidanceHint()
    }

    /// CoreML 힌트(디바운스 통과)를 우선 사용하고, CoreML이 활성화되지 않은 경우에만 Vision 메시지로 폴백한다.
    /// 한 번 표시된 힌트는 최소 표시 시간 동안은 숨기지 않아 깜빡임을 방지한다.
    @MainActor
    func updateActiveGuidanceHint() {
        let now = Date()
        var candidate: String? = nil

        // 1. CoreML 힌트 안정화
        if let hint = coreMLGuidanceHint {
            if pendingCoreMLHint == hint {
                if now.timeIntervalSince(pendingCoreMLHintSince) >= coreMLHintStabilityThreshold {
                    candidate = hint
                }
            } else {
                pendingCoreMLHint = hint
                pendingCoreMLHintSince = now
            }
        } else {
            pendingCoreMLHint = nil
            // CoreML이 한 번도 실행되지 않았을 때만 Vision guidanceMessage로 폴백한다.
            if inferenceScore == 0, !readyToCapture {
                let vision = guidanceMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                if !vision.isEmpty,
                   vision != "컨셉을 입력하면 구도 안내를 시작해요.",
                   vision != "카메라 권한이 필요해요." {
                    candidate = vision
                }
            }
        }

        // 2. 동일하면 업데이트 불필요
        guard activeGuidanceHint != candidate else { return }

        // 3. 힌트를 숨길 때는 최소 표시 시간을 지켜 깜빡임 방지
        if activeGuidanceHint != nil,
           candidate == nil,
           now.timeIntervalSince(activeHintAppliedAt) < coreMLHintMinDisplayDuration {
            return
        }

        activeGuidanceHint = candidate
        activeHintAppliedAt = now
    }

    func applyGuidanceResult(_ result: CompositionGuidanceResult) -> Bool {
        // 어떤 경로로 빠져나가든 최종 UI 힌트는 최신 상태로 재계산한다.
        defer { updateActiveGuidanceHint() }
        // 메시지를 UI에 반영하기 전에 점수/촬영 가능 상태는 즉시 업데이트한다.
        guidanceScore = result.evaluation.overallScore
        readyToCapture = result.evaluation.isAcceptable
        // 엔진의 평가 결과를 프리뷰 오버레이가 바로 그릴 수 있는 형태로 변환한다.
        overlayState = GuidanceOverlayState(
            targetRect: result.evaluation.target.overlayRect,
            detectedRect: result.evaluation.detectedSubjectRect,
            correction: result.evaluation.primaryCorrection,
            readyToCapture: result.evaluation.isAcceptable,
            profileName: result.evaluation.target.name,
            metrics: GuidanceDebugMetrics(
                score: result.evaluation.overallScore,
                xError: result.evaluation.xError,
                yError: result.evaluation.yError,
                sizeError: result.evaluation.sizeError,
                rollError: result.evaluation.rollError,
                stabilityError: result.evaluation.stabilityError
            )
        )

        // 신뢰도 낮은 결과는 사용자 혼란을 줄이기 위해 무시
        guard result.confidence >= minimumGuidanceConfidence else { return false }

        let message = result.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return false }

        let now = Date()
        // 방금 보여준 문구는 짧은 쿨다운 동안 재표시하지 않음
        if message == lastGuidanceMessage,
           now.timeIntervalSince(lastGuidanceAppliedAt) < repeatedGuidanceCooldown {
            return false
        }

        // 새 문구가 들어오면 우선 후보로 저장하고 디바운스 타이머 시작
        if pendingGuidanceMessage != message {
            pendingGuidanceMessage = message
            pendingGuidanceSince = now
            return false
        }

        // 동일 후보가 debounce 기간 이상 유지되면 실제 UI 반영
        guard now.timeIntervalSince(pendingGuidanceSince) >= guidanceDebounceInterval else { return false }

        guidanceMessage = message
        lastGuidanceMessage = message
        lastGuidanceAppliedAt = now
        pendingGuidanceMessage = nil
        return true
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let continuation = photoCaptureContinuation
        photoCaptureContinuation = nil

        Task { @MainActor in
            self.isCapturingPhoto = false
        }

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in
                self.errorMessage = error?.localizedDescription ?? "사진 캡처에 실패했어요."
            }
            continuation?.resume(returning: nil)
            return
        }
        continuation?.resume(returning: image)
    }
}
