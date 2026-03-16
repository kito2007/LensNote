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
    /// 최종적으로 사용자에게 보여줄 문구.
    let message: String
    /// 문구에 대한 신뢰도.
    let confidence: Double
    /// 모델/휴리스틱 중 어떤 경로에서 나온 결과인지.
    let source: CompositionGuidanceSource
    /// 데이터셋 기록용 feature 스냅샷.
    let featureSnapshot: CompositionFeatureSnapshot
    /// target 비교 기반 정량 평가 결과.
    let evaluation: CompositionEvaluation
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
    let devicePitch: Double?
    let deviceRoll: Double?
    let motionStable: Bool
    let overallScore: Double
    let readyToCapture: Bool
    let targetProfileName: String
}

/// 한 프레임에서 추출한 Vision/픽셀/motion 신호 묶음.
struct FrameFeatures {
    let faceObservation: VNFaceObservation?
    let saliencyCenter: CGPoint?
    let horizonAngle: Double?
    let brightness: Double
    let sharpness: Double
    let sceneType: SceneType
    let devicePose: DevicePose
}

struct ModelSuggestion {
    let message: String
    let confidence: Double
}

/// 모든 프레임을 다 분석하지 않고, 일정 간격으로만 추론하게 하는 스케줄러.
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
        frameCount += 1
        guard frameCount % targetFrameStride == 0 else { return false }

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

/// CoreML 모델이 있으면 우선 사용하고, 없으면 nil을 반환해 fallback을 유도한다.
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
        loadModelIfNeeded()
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
            let provider = try MLDictionaryFeatureProvider(dictionary: inputDictionary(for: features, model: model))
            let output = try model.prediction(from: provider)
            return decodeSuggestion(from: output)
        } catch {
            logger.warning("CompositionAssist inference failed. Falling back to heuristic guidance.")
            return nil
        }
    }

    private func loadModelIfNeeded() {
        guard !didAttemptLoading else { return }
        didAttemptLoading = true

        let bundle = Bundle.main
        if let compiledURL = bundle.url(forResource: modelName, withExtension: "mlmodelc"),
           let loaded = try? MLModel(contentsOf: compiledURL) {
            model = loaded
            return
        }

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
                dictionary[name] = MLFeatureValue(double: features.horizonAngle ?? features.devicePose.roll)
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
        if let text = firstStringValue(from: output, aliases: CompositionModelSchema.Output.guidanceText),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let confidence = firstDoubleValue(from: output, aliases: CompositionModelSchema.Output.confidence) ?? 0.55
            return ModelSuggestion(message: text, confidence: confidence)
        }

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

        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.faceCenterX, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.faceCenterY, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.faceSize, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.faceDetected, expectedTypes: [.int64, .double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.saliencyX, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.saliencyY, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.horizonAngle, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.brightness, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.sharpness, expectedTypes: [.double])
        validateRequiredFeature(category: "input", normalizedDescriptions: normalizedInputs, aliases: CompositionModelSchema.Input.sceneType, expectedTypes: [.int64, .double])

        validateRequiredFeature(category: "output", normalizedDescriptions: normalizedOutputs, aliases: CompositionModelSchema.Output.guidanceText, expectedTypes: [.string], required: false)
        validateRequiredFeature(category: "output", normalizedDescriptions: normalizedOutputs, aliases: CompositionModelSchema.Output.guidanceCode, expectedTypes: [.int64, .double], required: false)
        validateRequiredFeature(category: "output", normalizedDescriptions: normalizedOutputs, aliases: CompositionModelSchema.Output.confidence, expectedTypes: [.double], required: false)

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
    private var conceptHint: String = ""
    private var lastHeuristicMessage: String = ""
    private var heuristicRepeatCount: Int = 0

    init(
        scheduler: GuidanceInferenceScheduler = GuidanceInferenceScheduler(),
        modelService: CompositionModelServing = CoreMLCompositionModelService()
    ) {
        self.scheduler = scheduler
        self.modelService = modelService
    }

    func updateSceneHint(from concept: String) {
        conceptHint = concept
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

    func analyze(sampleBuffer: CMSampleBuffer, devicePose: DevicePose = .neutral) -> CompositionGuidanceResult? {
        // 성능/발열 관리를 위해 모든 프레임을 분석하지 않는다.
        guard scheduler.shouldRun() else { return nil }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        // Vision과 픽셀 기반 지표를 모아 현재 프레임의 상태를 만든다.
        let faceObservation = detectPrimaryFace(from: sampleBuffer)
        let visualSignals = detectSaliencyAndHorizon(from: sampleBuffer)
        let (brightness, sharpness) = estimateExposureAndSharpness(from: pixelBuffer)
        let features = FrameFeatures(
            faceObservation: faceObservation,
            saliencyCenter: visualSignals.saliencyCenter,
            horizonAngle: visualSignals.horizonAngle,
            brightness: brightness,
            sharpness: sharpness,
            sceneType: sceneHint,
            devicePose: devicePose
        )
        // 컨셉 기반 sceneHint를 실제 목표 구도 프리셋으로 변환.
        let target = CompositionTarget.preset(for: conceptHint, sceneType: sceneHint)
        // 현재 프레임이 목표 구도에서 얼마나 벗어났는지 계산.
        let evaluation = evaluate(features: features, target: target)
        let snapshot = snapshot(from: features, evaluation: evaluation)

        // 모델이 충분히 자신 있으면 모델 문구를 우선 사용한다.
        if let suggestion = modelService.suggestion(for: features), suggestion.confidence >= 0.55 {
            return CompositionGuidanceResult(
                message: suggestion.message,
                confidence: suggestion.confidence,
                source: .model,
                featureSnapshot: snapshot,
                evaluation: evaluation
            )
        }

        // 모델이 없거나 약하면 규칙 기반 correction을 문구로 사용한다.
        let heuristic = stabilizedHeuristicDecision(
            message: evaluation.primaryCorrection.message,
            baseConfidence: calibratedConfidence(from: evaluation)
        )
        return CompositionGuidanceResult(
            message: heuristic.message,
            confidence: heuristic.confidence,
            source: .heuristic,
            featureSnapshot: snapshot,
            evaluation: evaluation
        )
    }

    private func snapshot(from features: FrameFeatures, evaluation: CompositionEvaluation) -> CompositionFeatureSnapshot {
        // 나중에 오프라인 분석/학습에 활용할 수 있도록 평가 결과까지 함께 기록한다.
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
            sceneType: features.sceneType.rawValue,
            devicePitch: features.devicePose.pitch,
            deviceRoll: features.devicePose.roll,
            motionStable: features.devicePose.isStable,
            overallScore: evaluation.overallScore,
            readyToCapture: evaluation.isAcceptable,
            targetProfileName: evaluation.target.name
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

    private func evaluate(features: FrameFeatures, target: CompositionTarget) -> CompositionEvaluation {
        // target이 요구하는 대표 피사체를 현재 프레임에서 찾는다.
        let subject = subjectState(for: features, target: target)

        // 대표 피사체를 못 찾으면 다른 보정보다 "피사체 찾기"가 최우선이다.
        guard let subject else {
            return CompositionEvaluation(
                isAcceptable: false,
                overallScore: 0.22,
                xError: 1,
                yError: 1,
                sizeError: 1,
                rollError: 0,
                stabilityError: features.devicePose.isStable ? 0 : 0.6,
                primaryCorrection: .findSubject,
                target: target
            )
        }

        let xError = distanceToRange(subject.centerX, target.targetX)
        let yError = distanceToRange(subject.centerY, target.targetY)
        let sizeError = target.targetSize.map { distanceToRange(subject.size, $0) } ?? 0

        // Vision horizon이 있으면 우선 사용하고, 없으면 device roll을 fallback으로 사용.
        let measuredRoll = features.horizonAngle ?? features.devicePose.roll
        let rollMagnitude = abs(measuredRoll)
        let rollError = max(0, rollMagnitude - target.allowedRoll) / max(0.01, 0.22 - target.allowedRoll)

        // 흔들림은 motion 센서 기반, blur는 픽셀 sharpness 기반으로 본다.
        let stabilityError = features.devicePose.isStable ? 0 : min(1.0, (features.devicePose.rotationRate / 0.5) + (features.devicePose.userAcceleration / 0.15))

        let brightnessError: Double
        if features.brightness < 0.18 {
            brightnessError = min(1.0, (0.18 - features.brightness) / 0.18)
        } else if features.brightness > 0.9 {
            brightnessError = min(1.0, (features.brightness - 0.9) / 0.1)
        } else {
            brightnessError = 0
        }

        let sharpnessError = features.sharpness < 0.03 ? min(1.0, (0.03 - features.sharpness) / 0.03) : 0
        let headroomError = headroomError(for: features, target: target)

        // 각 오차를 가중합으로 합쳐 전체 score를 만든다.
        let weightedError =
            (xError * 0.23) +
            (yError * 0.18) +
            (sizeError * 0.18) +
            (rollError * 0.18) +
            (stabilityError * 0.13) +
            (brightnessError * 0.05) +
            (sharpnessError * 0.03) +
            (headroomError * 0.02)

        let overallScore = max(0, min(1, 1 - weightedError))
        // 사용자에게는 가장 중요한 correction 하나만 알려준다.
        let primaryCorrection = primaryCorrection(
            subject: subject,
            target: target,
            rollError: rollError,
            stabilityError: max(stabilityError, sharpnessError),
            brightnessError: brightnessError,
            isOverExposed: features.brightness > 0.9,
            headroomError: headroomError
        )
        let isAcceptable = overallScore >= 0.80 && primaryCorrection == .none

        return CompositionEvaluation(
            isAcceptable: isAcceptable,
            overallScore: overallScore,
            xError: xError,
            yError: yError,
            sizeError: sizeError,
            rollError: rollError,
            stabilityError: max(stabilityError, sharpnessError),
            primaryCorrection: primaryCorrection,
            target: target
        )
    }

    private func subjectState(for features: FrameFeatures, target: CompositionTarget) -> (centerX: Double, centerY: Double, size: Double)? {
        switch target.subjectKind {
        case .face:
            // 얼굴 중심 구도는 face bbox를 직접 사용.
            guard let face = features.faceObservation else { return nil }
            return (
                centerX: Double(face.boundingBox.midX),
                centerY: Double(face.boundingBox.midY),
                size: Double(face.boundingBox.width)
            )
        case .salientObject:
            // 풍경/음식 등은 saliency를 우선 사용하고, 없으면 face를 fallback으로 사용.
            if let saliency = features.saliencyCenter {
                let size = features.faceObservation.map { Double($0.boundingBox.width) } ?? 0.25
                return (centerX: Double(saliency.x), centerY: Double(saliency.y), size: size)
            }
            if let face = features.faceObservation {
                return (
                    centerX: Double(face.boundingBox.midX),
                    centerY: Double(face.boundingBox.midY),
                    size: Double(face.boundingBox.width)
                )
            }
            return nil
        case .none:
            // 특정 피사체가 없으면 화면 중앙을 기준값으로 둔다.
            return (centerX: 0.5, centerY: 0.5, size: 0.3)
        }
    }

    private func headroomError(for features: FrameFeatures, target: CompositionTarget) -> Double {
        // 얼굴 기반 프리셋에서만 머리 위 여백을 평가한다.
        guard let preferredHeadroom = target.preferredHeadroom,
              let face = features.faceObservation else {
            return 0
        }
        let headroom = Double(1 - face.boundingBox.maxY)
        return distanceToRange(headroom, preferredHeadroom)
    }

    private func primaryCorrection(
        subject: (centerX: Double, centerY: Double, size: Double),
        target: CompositionTarget,
        rollError: Double,
        stabilityError: Double,
        brightnessError: Double,
        isOverExposed: Bool,
        headroomError: Double
    ) -> GuidanceCorrection {
        // correction 우선순위는 "촬영 불가능한 큰 문제" -> "미세 구도 조정" 순서다.
        if rollError > 0.18 {
            return .levelHorizon
        }
        if stabilityError > 0.22 {
            return .holdSteady
        }
        if brightnessError > 0.3 {
            return isOverExposed ? .reduceHighlights : .brightenScene
        }
        if headroomError > 0.2 {
            return .adjustHeadroom
        }

        if subject.centerX < target.targetX.lowerBound {
            return .moveRight
        }
        if subject.centerX > target.targetX.upperBound {
            return .moveLeft
        }
        if subject.centerY < target.targetY.lowerBound {
            return .moveDown
        }
        if subject.centerY > target.targetY.upperBound {
            return .moveUp
        }

        if let targetSize = target.targetSize {
            if subject.size < targetSize.lowerBound {
                return .moveCloser
            }
            if subject.size > targetSize.upperBound {
                return .moveFarther
            }
        }

        if target.prefersRuleOfThirds {
            let nearestThird = nearestThirdDistance(subject.centerX)
            // 1/3 구도를 선호하는 장면은 중앙에서 조금 벗어나도록 유도한다.
            if nearestThird > 0.12 {
                return subject.centerX < 0.5 ? .moveRight : .moveLeft
            }
        }

        return .none
    }

    private func nearestThirdDistance(_ x: Double) -> Double {
        // 1/3선(1/3, 2/3) 중 더 가까운 쪽까지의 거리.
        min(abs(x - 1.0 / 3.0), abs(x - 2.0 / 3.0))
    }

    private func distanceToRange(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        // 범위 안이면 0, 밖이면 범위 폭 대비 얼마나 벗어났는지 0~1로 정규화.
        if range.contains(value) { return 0 }
        if value < range.lowerBound {
            return min(1, (range.lowerBound - value) / max(0.0001, range.upperBound - range.lowerBound))
        }
        return min(1, (value - range.upperBound) / max(0.0001, range.upperBound - range.lowerBound))
    }

    private func calibratedConfidence(from evaluation: CompositionEvaluation) -> Double {
        // score를 사람이 읽기 쉬운 confidence 범위로 보정.
        let base = 0.48 + (evaluation.overallScore * 0.3)
        if evaluation.primaryCorrection == .none {
            return min(0.82, base)
        }
        return min(0.82, base + 0.04)
    }

    private func stabilizedHeuristicDecision(message: String, baseConfidence: Double) -> ModelSuggestion {
        // 동일 문구가 반복되면 confidence를 조금 올려 UI 흔들림을 줄인다.
        if message == lastHeuristicMessage {
            heuristicRepeatCount += 1
        } else {
            lastHeuristicMessage = message
            heuristicRepeatCount = 1
        }

        let boost = min(0.14, Double(max(0, heuristicRepeatCount - 1)) * 0.03)
        let calibrated = min(0.82, baseConfidence + boost)
        return ModelSuggestion(message: message, confidence: calibrated)
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

        let stride = 8
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var brightnessSum = 0.0
        var gradientSum = 0.0
        var sampleCount = 0

        // 모든 픽셀을 다 읽지 않고 일정 stride 간격으로만 샘플링한다.
        for y in stride..<(height - stride) where y % stride == 0 {
            var previousLuma = 0.0
            for x in stride..<(width - stride) where x % stride == 0 {
                let offset = y * bytesPerRow + (x * 4)
                let b = Double(pointer[offset])
                let g = Double(pointer[offset + 1])
                let r = Double(pointer[offset + 2])
                // RGB를 밝기(luma) 하나로 바꿔 평균 밝기를 구한다.
                let luma = (0.114 * b + 0.587 * g + 0.299 * r) / 255.0

                brightnessSum += luma
                if sampleCount > 0 {
                    // 인접 샘플 간 밝기 차이를 간단한 edge/선명도 지표로 사용.
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
