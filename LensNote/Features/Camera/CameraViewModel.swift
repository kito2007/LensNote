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

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    private let savePhotoUseCase: SavePhotoUseCase

    @Published var lastSaved: PhotoItem? = nil
    @Published var errorMessage: String? = nil

    @Published var conceptText: String = ""
    @Published var preset: FilterPreset? = nil
    @Published var guidanceMessage: String = "컨셉을 입력하면 구도 안내를 시작해요."
    @Published var isCameraAuthorized: Bool? = nil
    @Published var isCapturingPhoto: Bool = false
    @Published var cameraStatusMessage: String? = nil

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
    private let sampleBufferQueue = DispatchQueue(label: "CameraSampleBufferQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    // 카메라 프레임 -> 구도 가이드 결과를 만드는 엔진
    private nonisolated(unsafe) let guidanceEngine = CompositionGuidanceEngine()
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

    init(savePhotoUseCase: SavePhotoUseCase) {
        self.savePhotoUseCase = savePhotoUseCase
        super.init()
    }

    func applyConcept() {
        preset = presetForConcept(conceptText)
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
            }
        }
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

    func saveCapturedImage(_ image: UIImage, coordinate: GeoCoordinate? = nil) {
        do {
            let filePath = try persistImageToDocuments(image)
            let saved = try savePhotoUseCase.execute(imagePath: filePath, coordinate: coordinate)
            lastSaved = saved
            errorMessage = nil
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

    private func presetForConcept(_ text: String) -> FilterPreset {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if keyword.contains("무드") || keyword.contains("시네마") || keyword.contains("cinematic") {
            return FilterPreset(name: "Cinematic", exposure: -0.1, contrast: 0.25, saturation: -0.05, temperature: -0.05, vignette: 0.4)
        }
        if keyword.contains("빈티지") || keyword.contains("필름") || keyword.contains("vintage") {
            return FilterPreset(name: "Vintage", exposure: 0.05, contrast: -0.1, saturation: -0.15, temperature: 0.15, vignette: 0.35)
        }
        if keyword.contains("따뜻") || keyword.contains("warm") {
            return FilterPreset(name: "Warm", exposure: 0.1, contrast: 0.1, saturation: 0.1, temperature: 0.2, vignette: 0.2)
        }
        if keyword.contains("차가") || keyword.contains("cool") {
            return FilterPreset(name: "Cool", exposure: 0.0, contrast: 0.1, saturation: 0.05, temperature: -0.2, vignette: 0.15)
        }
        return FilterPreset(name: "Standard", exposure: 0.0, contrast: 0.0, saturation: 0.0, temperature: 0.0, vignette: 0.0)
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
        guard let result = guidanceEngine.analyze(sampleBuffer: sampleBuffer) else { return }
        Task { @MainActor [weak self] in
            // 고빈도 프레임 이벤트에서 바로 UI 반영하지 않고 안정화 로직 통과
            self?.applyGuidanceResult(result)
        }
    }
}

private extension CameraViewModel {
    func applyGuidanceResult(_ result: CompositionGuidanceResult) {
        // 신뢰도 낮은 결과는 사용자 혼란을 줄이기 위해 무시
        guard result.confidence >= minimumGuidanceConfidence else { return }

        let message = result.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        let now = Date()
        // 방금 보여준 문구는 짧은 쿨다운 동안 재표시하지 않음
        if message == lastGuidanceMessage,
           now.timeIntervalSince(lastGuidanceAppliedAt) < repeatedGuidanceCooldown {
            return
        }

        // 새 문구가 들어오면 우선 후보로 저장하고 디바운스 타이머 시작
        if pendingGuidanceMessage != message {
            pendingGuidanceMessage = message
            pendingGuidanceSince = now
            return
        }

        // 동일 후보가 debounce 기간 이상 유지되면 실제 UI 반영
        guard now.timeIntervalSince(pendingGuidanceSince) >= guidanceDebounceInterval else { return }

        guidanceMessage = message
        lastGuidanceMessage = message
        lastGuidanceAppliedAt = now
        pendingGuidanceMessage = nil
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
