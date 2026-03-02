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
import OSLog

private enum CompositionModelSchema {
    enum Input {
        static let faceCenterX = ["face_center_x", "face_x"]
        static let faceCenterY = ["face_center_y", "face_y"]
        static let faceSize = ["face_size", "face_width"]
        static let faceDetected = ["face_detected", "has_face"]
        static let saliencyX = ["saliency_x", "attention_x"]
        static let saliencyY = ["saliency_y", "attention_y"]
        static let horizonAngle = ["horizon_angle", "roll"]
        static let brightness = ["brightness", "exposure"]
        static let sharpness = ["sharpness", "blur_score"]
        static let sceneType = ["scene_type", "scene"]
    }

    enum Output {
        static let guidanceText = ["guidance_text"]
        static let guidanceCode = ["guidance_code"]
        static let confidence = ["confidence", "score"]
    }
}

struct CompositionGuidanceResult {
    // UI에 보여줄 최종 가이드 문구
    let message: String
    // 엔진이 판단한 결과 신뢰도(0~1)
    let confidence: Double
    // 어떤 경로에서 나온 결과인지(모델/규칙)
    let source: CompositionGuidanceSource
    // 학습/분석용 숫자 피처 스냅샷
    let featureSnapshot: CompositionFeatureSnapshot
}

enum CompositionGuidanceSource: String, Codable {
    case model
    case heuristic
}

struct CompositionFeatureSnapshot: Codable {
    let faceDetected: Bool
    let faceCenterX: Double?
    let faceCenterY: Double?
    let faceSize: Double?
    let saliencyX: Double?
    let saliencyY: Double?
    let horizonAngle: Double?
    let brightness: Double
    let sharpness: Double
    let sceneType: String
}

struct FrameFeatures {
    // 현재 프레임에서 감지된 대표 얼굴(없으면 nil)
    let faceObservation: VNFaceObservation?
    // Vision Saliency 기반 주목 영역 중심(정규화 좌표, 없으면 nil)
    let saliencyCenter: CGPoint?
    // 수평선 기울기(라디안, 없으면 nil)
    let horizonAngle: Double?
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
    private var didLogMissingModel = false
    private var didValidateSchema = false
    private let logger = Logger(subsystem: "LensNote", category: "CompositionModel")

    init(modelName: String = "CompositionAssist") {
        self.modelName = modelName
    }

    func suggestion(for features: FrameFeatures) -> ModelSuggestion? {
        // 모델 로드는 최초 1회만 시도
        loadModelIfNeeded()
        // 모델이 없으면 상위 엔진이 규칙 기반 fallback을 사용
        guard let model else {
            if !didLogMissingModel {
                logger.info("CompositionAssist model not found. Using Vision + heuristic fallback.")
                didLogMissingModel = true
            }
            return nil
        }
        if !didValidateSchema {
            validateModelSchema(model)
            didValidateSchema = true
        }

        do {
            // 모델 입력 스키마에 맞춰 동적 피처 딕셔너리 생성
            let provider = try MLDictionaryFeatureProvider(dictionary: inputDictionary(for: features, model: model))
            let output = try model.prediction(from: provider)
            return decodeSuggestion(from: output)
        } catch {
            // 추론 실패 시에도 앱 동작을 멈추지 않고 fallback으로 진행
            logger.warning("CompositionAssist inference failed. Falling back to heuristic guidance.")
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
            let normalized = normalizeFeatureName(name)
            // 모델 입력명을 스키마 별칭으로 매칭해 타입 안전하게 값 공급
            if CompositionModelSchema.Input.faceCenterX.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: Double(features.faceObservation?.boundingBox.midX ?? 0.5))
            } else if CompositionModelSchema.Input.faceCenterY.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: Double(features.faceObservation?.boundingBox.midY ?? 0.5))
            } else if CompositionModelSchema.Input.faceSize.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: Double(features.faceObservation?.boundingBox.width ?? 0.0))
            } else if CompositionModelSchema.Input.faceDetected.contains(normalized) {
                dictionary[name] = MLFeatureValue(int64: features.faceObservation == nil ? 0 : 1)
            } else if CompositionModelSchema.Input.saliencyX.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: Double(features.saliencyCenter?.x ?? 0.5))
            } else if CompositionModelSchema.Input.saliencyY.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: Double(features.saliencyCenter?.y ?? 0.5))
            } else if CompositionModelSchema.Input.horizonAngle.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: features.horizonAngle ?? 0.0)
            } else if CompositionModelSchema.Input.brightness.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: features.brightness)
            } else if CompositionModelSchema.Input.sharpness.contains(normalized) {
                dictionary[name] = MLFeatureValue(double: features.sharpness)
            } else if CompositionModelSchema.Input.sceneType.contains(normalized) {
                dictionary[name] = MLFeatureValue(int64: Int64(sceneIndex(features.sceneType)))
            } else {
                dictionary[name] = MLFeatureValue(double: 0)
            }
        }

        return dictionary
    }

    private func decodeSuggestion(from output: MLFeatureProvider) -> ModelSuggestion? {
        // 1순위: 모델이 직접 텍스트를 주는 경우
        if let text = firstStringValue(from: output, aliases: CompositionModelSchema.Output.guidanceText),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let confidence = firstDoubleValue(from: output, aliases: CompositionModelSchema.Output.confidence) ?? 0.55
            return ModelSuggestion(message: text, confidence: confidence)
        }

        // 2순위: 코드값을 반환하는 경우 앱 문구로 매핑
        if let code = firstInt64Value(from: output, aliases: CompositionModelSchema.Output.guidanceCode) {
            let mapped = mappedMessage(code: code)
            if !mapped.isEmpty {
                let confidence = firstDoubleValue(from: output, aliases: CompositionModelSchema.Output.confidence) ?? 0.52
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

    private func normalizeFeatureName(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func firstStringValue(from output: MLFeatureProvider, aliases: [String]) -> String? {
        for alias in aliases {
            if let value = output.featureValue(for: alias)?.stringValue {
                return value
            }
        }
        return nil
    }

    private func firstDoubleValue(from output: MLFeatureProvider, aliases: [String]) -> Double? {
        for alias in aliases {
            if let value = output.featureValue(for: alias)?.doubleValue {
                return value
            }
        }
        return nil
    }

    private func firstInt64Value(from output: MLFeatureProvider, aliases: [String]) -> Int64? {
        for alias in aliases {
            if let value = output.featureValue(for: alias)?.int64Value {
                return value
            }
        }
        return nil
    }

    private func validateModelSchema(_ model: MLModel) {
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        let outputDescriptions = model.modelDescription.outputDescriptionsByName
        let normalizedInputs = Dictionary(uniqueKeysWithValues: inputDescriptions.map { (normalizeFeatureName($0.key), $0.value) })
        let normalizedOutputs = Dictionary(uniqueKeysWithValues: outputDescriptions.map { (normalizeFeatureName($0.key), $0.value) })

        // 필수 입력/출력의 존재 여부를 먼저 검증
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.faceCenterX,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.faceCenterY,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.faceSize,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.faceDetected,
            expectedTypes: [.int64, .double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.saliencyX,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.saliencyY,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.horizonAngle,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.brightness,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.sharpness,
            expectedTypes: [.double]
        )
        validateRequiredFeature(
            category: "input",
            normalizedDescriptions: normalizedInputs,
            aliases: CompositionModelSchema.Input.sceneType,
            expectedTypes: [.int64, .double]
        )

        validateRequiredFeature(
            category: "output",
            normalizedDescriptions: normalizedOutputs,
            aliases: CompositionModelSchema.Output.guidanceText,
            expectedTypes: [.string],
            required: false
        )
        validateRequiredFeature(
            category: "output",
            normalizedDescriptions: normalizedOutputs,
            aliases: CompositionModelSchema.Output.guidanceCode,
            expectedTypes: [.int64, .double],
            required: false
        )
        validateRequiredFeature(
            category: "output",
            normalizedDescriptions: normalizedOutputs,
            aliases: CompositionModelSchema.Output.confidence,
            expectedTypes: [.double],
            required: false
        )

        logger.info("CompositionAssist schema validation finished.")
    }

    private func validateRequiredFeature(
        category: String,
        normalizedDescriptions: [String: MLFeatureDescription],
        aliases: [String],
        expectedTypes: [MLFeatureType],
        required: Bool = true
    ) {
        guard let matchedAlias = aliases.first(where: { normalizedDescriptions[$0] != nil }) else {
            if required {
                logger.warning("Missing \(category, privacy: .public) feature. Expected one of: \(aliases.joined(separator: ","), privacy: .public)")
            }
            return
        }

        guard let description = normalizedDescriptions[matchedAlias] else { return }
        if !expectedTypes.contains(description.type) {
            let expected = expectedTypes.map { String(describing: $0) }.joined(separator: ",")
            logger.warning("Type mismatch for \(category, privacy: .public) '\(matchedAlias, privacy: .public)'. Expected: \(expected, privacy: .public), actual: \(String(describing: description.type), privacy: .public)")
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
            return nil
        }

        // 프레임 피처 추출(얼굴 + 밝기 + 선명도 + 씬 힌트)
        let faceObservation = detectPrimaryFace(from: sampleBuffer)
        let visualSignals = detectSaliencyAndHorizon(from: sampleBuffer)
        let (brightness, sharpness) = estimateExposureAndSharpness(from: pixelBuffer)
        let features = FrameFeatures(
            faceObservation: faceObservation,
            saliencyCenter: visualSignals.saliencyCenter,
            horizonAngle: visualSignals.horizonAngle,
            brightness: brightness,
            sharpness: sharpness,
            sceneType: sceneHint
        )
        let snapshot = snapshot(from: features)

        // 모델 결과가 충분히 신뢰 가능하면 우선 사용
        if let suggestion = modelService.suggestion(for: features), suggestion.confidence >= 0.55 {
            return CompositionGuidanceResult(
                message: suggestion.message,
                confidence: suggestion.confidence,
                source: .model,
                featureSnapshot: snapshot
            )
        }

        // 모델이 없거나 신뢰도가 낮으면 규칙 기반 문구로 fallback
        return CompositionGuidanceResult(
            message: heuristicGuidance(from: features),
            confidence: 0.45,
            source: .heuristic,
            featureSnapshot: snapshot
        )
    }

    private func snapshot(from features: FrameFeatures) -> CompositionFeatureSnapshot {
        CompositionFeatureSnapshot(
            faceDetected: features.faceObservation != nil,
            faceCenterX: features.faceObservation.map { Double($0.boundingBox.midX) },
            faceCenterY: features.faceObservation.map { Double($0.boundingBox.midY) },
            faceSize: features.faceObservation.map { Double($0.boundingBox.width) },
            saliencyX: features.saliencyCenter.map { Double($0.x) },
            saliencyY: features.saliencyCenter.map { Double($0.y) },
            horizonAngle: features.horizonAngle,
            brightness: features.brightness,
            sharpness: features.sharpness,
            sceneType: features.sceneType.rawValue
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

    private func detectSaliencyAndHorizon(from sampleBuffer: CMSampleBuffer) -> (saliencyCenter: CGPoint?, horizonAngle: Double?) {
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let horizonRequest = VNDetectHorizonRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([saliencyRequest, horizonRequest])

            var saliencyCenter: CGPoint?
            if let observation = (saliencyRequest.results as? [VNSaliencyImageObservation])?.first {
                let strongest = observation.salientObjects?.max { $0.confidence < $1.confidence }
                if let strongest {
                    saliencyCenter = CGPoint(x: strongest.boundingBox.midX, y: strongest.boundingBox.midY)
                }
            }

            let horizon = (horizonRequest.results as? [VNHorizonObservation])?.first
            let horizonAngle = horizon.map { Double($0.angle) }
            return (saliencyCenter, horizonAngle)
        } catch {
            return (nil, nil)
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

        // 풍경/도시 씬에서 수평 기울기를 먼저 보정
        if let horizonAngle = features.horizonAngle, abs(horizonAngle) > 0.08 {
            return "수평이 기울었어요. 화면의 수평선을 맞춰보세요."
        }

        // Saliency 중심이 중앙에 너무 모이면 1/3 지점 배치를 유도
        if let saliencyCenter = features.saliencyCenter,
           features.sceneType == .landscape || features.sceneType == .cityStreet {
            if (0.42...0.58).contains(saliencyCenter.x) {
                return "주 피사체를 1/3 지점으로 옮겨보세요."
            }
            if saliencyCenter.x < 0.28 {
                return "주 피사체가 왼쪽에 몰렸어요. 조금 오른쪽으로 이동해보세요."
            }
            if saliencyCenter.x > 0.72 {
                return "주 피사체가 오른쪽에 몰렸어요. 조금 왼쪽으로 이동해보세요."
            }
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
