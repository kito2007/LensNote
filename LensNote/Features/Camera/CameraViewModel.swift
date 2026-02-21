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
import Vision

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

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
    private let sampleBufferQueue = DispatchQueue(label: "CameraSampleBufferQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private nonisolated(unsafe) var lastAnalysisTime = Date.distantPast
    private nonisolated let analysisInterval: TimeInterval = 0.2
    private var isSessionConfigured = false
    private var isRunning = false

    init(savePhotoUseCase: SavePhotoUseCase) {
        self.savePhotoUseCase = savePhotoUseCase
        super.init()
    }

    func applyConcept() {
        preset = presetForConcept(conceptText)
    }

    func startSessionIfNeeded() async {
        guard !isRunning else { return }

        let granted = await requestCameraAccess()
        isCameraAuthorized = granted
        guard granted else {
            guidanceMessage = "카메라 권한이 필요해요."
            return
        }

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

                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)

                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }

                if let connection = self.videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
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

    private func updateGuidance(with observation: VNFaceObservation?) {
        guard let observation else {
            guidanceMessage = "인물이 화면 안에 들어오도록 맞춰주세요."
            return
        }

        let bbox = observation.boundingBox
        let centerX = bbox.midX
        let centerY = bbox.midY
        let width = bbox.width

        if width < 0.18 {
            guidanceMessage = "조금 더 가까이"
        } else if width > 0.55 {
            guidanceMessage = "조금 더 멀리"
        } else if centerX < 0.4 {
            guidanceMessage = "조금 더 오른쪽으로"
        } else if centerX > 0.6 {
            guidanceMessage = "조금 더 왼쪽으로"
        } else if centerY < 0.35 {
            guidanceMessage = "조금 더 아래로"
        } else if centerY > 0.65 {
            guidanceMessage = "조금 더 위로"
        } else {
            guidanceMessage = "좋아요! 지금 구도 유지"
        }
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        if now.timeIntervalSince(lastAnalysisTime) < analysisInterval {
            return
        }
        lastAnalysisTime = now

        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let self else { return }
            let face = (request.results as? [VNFaceObservation])?.first
            Task { @MainActor in
                self.updateGuidance(with: face)
            }
        }

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .right,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            Task { @MainActor in
                self.guidanceMessage = "구도 분석에 실패했어요."
            }
        }
    }
}

