//
//  CompositionGuidanceEngine.swift
//  LensNote
//
//  Created by Codex on 2/23/26.
//

import Foundation
import AVFoundation
import CoreML
import UIKit
import Vision

struct CompositionGuidanceResult {
    // UI에 보여줄 최종 가이드 문구
    let message: String
    // 엔진이 판단한 결과 신뢰도(0~1)
    let confidence: Double
}

struct FrameFeatures {
    // 현재 프레임에서 감지된 대표 얼굴(없으면 nil)
    let faceObservation: VNFaceObservation?
    // 0~1 범위 밝기 추정치
    let brightness: Double
    // 프레임 내 에지 변화량 기반 선명도(간이 지표)
    let sharpness: Double
    // 컨셉 텍스트에서 추론한 씬 힌트
    let sceneType: SceneType
}

struct ModelSuggestion {
    // 모델이 제안한 가이드 문구
    let message: String
    // 모델 출력 신뢰도
    let confidence: Double
}

final class GuidanceInferenceScheduler {
    private let targetFrameStride: Int
    private let baseInterval: TimeInterval
    private var frameCount: Int = 0
    private var lastInferenceTime = Date.distantPast

    init(targetFrameStride: Int = 10, baseInterval: TimeInterval = 0.35) {
        self.targetFrameStride = max(1, targetFrameStride)
        self.baseInterval = max(0.1, baseInterval)
    }

    func shouldRun(now: Date = Date()) -> Bool {
        // 1) 프레임 스트라이드 기준(예: 10프레임마다)으로 1차 필터링
        frameCount += 1
        guard frameCount % targetFrameStride == 0 else { return false }

        // 2) 마지막 추론 시점과의 시간 간격으로 2차 필터링
        //    (저전력/열 상태에 따라 간격이 동적으로 늘어남)
        let elapsed = now.timeIntervalSince(lastInferenceTime)
        guard elapsed >= currentInterval else { return false }

        lastInferenceTime = now
        return true
    }

    private var currentInterval: TimeInterval {
        var interval = baseInterval
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            interval += 0.2
        }

        switch ProcessInfo.processInfo.thermalState {
        case .fair:
            interval += 0.1
        case .serious:
            interval += 0.35
        case .critical:
            interval += 0.6
        case .nominal:
            break
        @unknown default:
            interval += 0.2
        }
        return min(1.2, max(0.2, interval))
    }
}

protocol CompositionModelServing {
    func suggestion(for features: FrameFeatures) -> ModelSuggestion?
}

final class CoreMLCompositionModelService: CompositionModelServing {
    private let modelName: String
    private var model: MLModel?
    private var didAttemptLoading = false

    init(modelName: String = "CompositionAssist") {
        self.modelName = modelName
    }

    func suggestion(for features: FrameFeatures) -> ModelSuggestion? {
        // 모델 로드는 최초 1회만 시도
        loadModelIfNeeded()
        // 모델이 없으면 상위 엔진이 규칙 기반 fallback을 사용
        guard let model else { return nil }

        do {
            // 모델 입력 스키마에 맞춰 동적 피처 딕셔너리 생성
            let provider = try MLDictionaryFeatureProvider(dictionary: inputDictionary(for: features, model: model))
            let output = try model.prediction(from: provider)
            return decodeSuggestion(from: output)
        } catch {
            // 추론 실패 시에도 앱 동작을 멈추지 않고 fallback으로 진행
            return nil
        }
    }

    private func loadModelIfNeeded() {
        guard !didAttemptLoading else { return }
        didAttemptLoading = true

        let bundle = Bundle.main
        // 우선 컴파일된 모델(.mlmodelc) 탐색
        if let compiledURL = bundle.url(forResource: modelName, withExtension: "mlmodelc"),
           let loaded = try? MLModel(contentsOf: compiledURL) {
            model = loaded
            return
        }

        // 없으면 원본(.mlmodel)을 런타임 컴파일해 로드 시도
        if let sourceURL = bundle.url(forResource: modelName, withExtension: "mlmodel"),
           let compiledURL = try? MLModel.compileModel(at: sourceURL),
           let loaded = try? MLModel(contentsOf: compiledURL) {
            model = loaded
        }
    }

    private func inputDictionary(for features: FrameFeatures, model: MLModel) -> [String: MLFeatureValue] {
        let inputNames = model.modelDescription.inputDescriptionsByName.keys
        var dictionary: [String: MLFeatureValue] = [:]

        for name in inputNames {
            let lower = name.lowercased()
            // 모델 키 이름 일부를 기준으로 값을 매핑하는 유연한 방식
            // (정식 스키마 확정 전 MVP 단계에서 키 변화에 덜 취약)
            if lower.contains("face_center_x") {
                dictionary[name] = MLFeatureValue(double: Double(features.faceObservation?.boundingBox.midX ?? 0.5))
            } else if lower.contains("face_center_y") {
                dictionary[name] = MLFeatureValue(double: Double(features.faceObservation?.boundingBox.midY ?? 0.5))
            } else if lower.contains("face_size") {
                dictionary[name] = MLFeatureValue(double: Double(features.faceObservation?.boundingBox.width ?? 0.0))
            } else if lower.contains("face_detected") {
                dictionary[name] = MLFeatureValue(int64: features.faceObservation == nil ? 0 : 1)
            } else if lower.contains("brightness") || lower.contains("exposure") {
                dictionary[name] = MLFeatureValue(double: features.brightness)
            } else if lower.contains("sharpness") || lower.contains("blur") {
                dictionary[name] = MLFeatureValue(double: features.sharpness)
            } else if lower.contains("scene") {
                dictionary[name] = MLFeatureValue(int64: Int64(sceneIndex(features.sceneType)))
            } else {
                dictionary[name] = MLFeatureValue(double: 0)
            }
        }

        return dictionary
    }

    private func decodeSuggestion(from output: MLFeatureProvider) -> ModelSuggestion? {
        // 1순위: 모델이 직접 텍스트를 주는 경우
        if let text = output.featureValue(for: "guidance_text")?.stringValue,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let confidence = output.featureValue(for: "confidence")?.doubleValue ?? 0.55
            return ModelSuggestion(message: text, confidence: confidence)
        }

        // 2순위: 코드값을 반환하는 경우 앱 문구로 매핑
        if let code = output.featureValue(for: "guidance_code")?.int64Value {
            let mapped = mappedMessage(code: code)
            if !mapped.isEmpty {
                let confidence = output.featureValue(for: "confidence")?.doubleValue ?? 0.52
                return ModelSuggestion(message: mapped, confidence: confidence)
            }
        }

        return nil
    }

    private func mappedMessage(code: Int64) -> String {
        switch code {
        case 1: return "조금 더 오른쪽으로 이동해보세요."
        case 2: return "조금 더 왼쪽으로 이동해보세요."
        case 3: return "카메라를 약간 아래로 내려보세요."
        case 4: return "카메라를 약간 위로 올려보세요."
        case 5: return "한 발짝만 더 가까이 가보세요."
        case 6: return "한 발짝만 더 물러나 보세요."
        default: return ""
        }
    }

    private func sceneIndex(_ sceneType: SceneType) -> Int {
        switch sceneType {
        case .portrait: return 0
        case .landscape: return 1
        case .cityStreet: return 2
        case .food: return 3
        case .night: return 4
        case .pet: return 5
        case .etc: return 6
        }
    }
}

final class CompositionGuidanceEngine {
    private let scheduler: GuidanceInferenceScheduler
    private let modelService: CompositionModelServing
    private var sceneHint: SceneType = .etc

    init(
        scheduler: GuidanceInferenceScheduler = GuidanceInferenceScheduler(),
        modelService: CompositionModelServing = CoreMLCompositionModelService()
    ) {
        self.scheduler = scheduler
        self.modelService = modelService
    }

    func updateSceneHint(from concept: String) {
        // 사용자가 입력한 컨셉 텍스트를 씬 타입으로 변환해
        // 이후 규칙/모델 추론의 문맥 힌트로 활용
        let normalized = concept.lowercased()

        if normalized.contains("인물") || normalized.contains("portrait") {
            sceneHint = .portrait
        } else if normalized.contains("풍경") || normalized.contains("landscape") {
            sceneHint = .landscape
        } else if normalized.contains("야경") || normalized.contains("night") {
            sceneHint = .night
        } else if normalized.contains("음식") || normalized.contains("food") {
            sceneHint = .food
        } else if normalized.contains("거리") || normalized.contains("도시") || normalized.contains("street") {
            sceneHint = .cityStreet
        } else if normalized.contains("반려") || normalized.contains("펫") || normalized.contains("pet") {
            sceneHint = .pet
        } else {
            sceneHint = .etc
        }
    }

    func analyze(sampleBuffer: CMSampleBuffer) -> CompositionGuidanceResult? {
        // 스케줄러가 허용한 시점에만 분석하여 발열/배터리 비용 제어
        guard scheduler.shouldRun() else { return nil }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return CompositionGuidanceResult(message: "프레임을 읽을 수 없어 분석을 건너뛰었어요.", confidence: 0.2)
        }

        // 프레임 피처 추출(얼굴 + 밝기 + 선명도 + 씬 힌트)
        let faceObservation = detectPrimaryFace(from: sampleBuffer)
        let (brightness, sharpness) = estimateExposureAndSharpness(from: pixelBuffer)
        let features = FrameFeatures(
            faceObservation: faceObservation,
            brightness: brightness,
            sharpness: sharpness,
            sceneType: sceneHint
        )

        // 모델 결과가 충분히 신뢰 가능하면 우선 사용
        if let suggestion = modelService.suggestion(for: features), suggestion.confidence >= 0.55 {
            return CompositionGuidanceResult(message: suggestion.message, confidence: suggestion.confidence)
        }

        // 모델이 없거나 신뢰도가 낮으면 규칙 기반 문구로 fallback
        return CompositionGuidanceResult(
            message: heuristicGuidance(from: features),
            confidence: 0.45
        )
    }

    private func detectPrimaryFace(from sampleBuffer: CMSampleBuffer) -> VNFaceObservation? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([request])
            return (request.results as? [VNFaceObservation])?.first
        } catch {
            return nil
        }
    }

    private func heuristicGuidance(from features: FrameFeatures) -> String {
        // 인물이 검출되면 기존 구도 규칙(거리/좌우/상하) 우선 적용
        if let face = features.faceObservation {
            let bbox = face.boundingBox
            let centerX = bbox.midX
            let centerY = bbox.midY
            let width = bbox.width

            if width < 0.18 {
                return "조금 더 가까이"
            }
            if width > 0.55 {
                return "조금 더 멀리"
            }
            if centerX < 0.4 {
                return "조금 더 오른쪽으로"
            }
            if centerX > 0.6 {
                return "조금 더 왼쪽으로"
            }
            if centerY < 0.35 {
                return "조금 더 아래로"
            }
            if centerY > 0.65 {
                return "조금 더 위로"
            }
        } else if features.sceneType == .portrait || features.sceneType == .pet {
            return "인물이 화면 안에 들어오도록 맞춰주세요."
        }

        // 인물이 없을 때는 밝기/선명도 기반 촬영 안정화 가이드 제공
        if features.brightness < 0.18 {
            return "조명이 부족해요. 조금 더 밝은 방향으로 이동해보세요."
        }
        if features.brightness > 0.9 {
            return "노출이 높아요. 밝은 영역을 화면 밖으로 조금 이동해보세요."
        }
        if features.sharpness < 0.03 {
            return "손떨림이 감지돼요. 잠시 멈춘 뒤 촬영해보세요."
        }

        return "좋아요! 지금 구도 유지"
    }

    private func estimateExposureAndSharpness(from pixelBuffer: CVPixelBuffer) -> (brightness: Double, sharpness: Double) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return (0.5, 0.05)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // 모든 픽셀을 보지 않고 stride 샘플링으로 계산 비용 절감
        let stride = 8
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var brightnessSum = 0.0
        var gradientSum = 0.0
        var sampleCount = 0

        for y in stride..<(height - stride) where y % stride == 0 {
            var previousLuma = 0.0
            for x in stride..<(width - stride) where x % stride == 0 {
                let offset = y * bytesPerRow + (x * 4)
                let b = Double(pointer[offset])
                let g = Double(pointer[offset + 1])
                let r = Double(pointer[offset + 2])
                // RGB -> luma 변환으로 밝기 계산
                let luma = (0.114 * b + 0.587 * g + 0.299 * r) / 255.0

                brightnessSum += luma
                if sampleCount > 0 {
                    // 인접 샘플의 밝기 차이를 선명도(에지 변화)로 근사
                    gradientSum += abs(luma - previousLuma)
                }
                previousLuma = luma
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return (0.5, 0.05) }
        let meanBrightness = brightnessSum / Double(sampleCount)
        let sharpness = gradientSum / Double(sampleCount)
        return (meanBrightness, sharpness)
    }
}
