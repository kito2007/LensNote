//
//  MobileNetV2Service.swift
//  LensNote
//
//  Created by LensNote Engineer on 2026-04-06.
//

import Foundation
import CoreML
import Vision
import CoreVideo

/// MobileNetV2 장면 분류 결과.
struct SceneClassificationResult {
    let sceneType: SceneType
    let rawLabel: String
    let confidence: Double
}

/// MobileNetV2 CoreML 모델을 래핑하여 장면 분류를 수행하는 서비스.
/// nonisolated — 세션 큐(sampleBufferQueue)에서 직접 호출한다.
final class MobileNetV2Service {

    // MARK: - ImageNet label -> SceneType 매핑 테이블

    private static let portraitLabels: Set<String> = [
        "bridegroom", "suit", "cowboy hat", "mortarboard", "military uniform",
        "academic gown", "wig", "maillot", "bikini", "brassiere"
    ]

    private static let landscapeLabels: Set<String> = [
        "alp", "valley", "cliff", "promontory", "seashore", "lakeside",
        "mountain tent", "geyser", "volcano", "coral reef", "sandbar",
        "stone wall", "dam", "suspension bridge", "viaduct"
    ]

    private static let cityStreetLabels: Set<String> = [
        "street sign", "traffic light", "traffic cam", "parking meter",
        "pay-phone", "fire station", "barbershop", "bookshop", "grocery store",
        "shoe shop", "toyshop", "confectionery", "china cabinet", "cinema",
        "restaurant", "library", "prison", "pier"
    ]

    private static let foodLabels: Set<String> = [
        "pizza", "hamburger", "hotdog", "cheeseburger", "burrito",
        "pretzel", "bagel", "bread", "bun", "spaghetti", "ramen",
        "taco", "guacamole", "ice cream", "chocolate sauce",
        "cup", "espresso", "teapot", "coffee mug", "eggnog",
        "red wine", "beer bottle", "plate", "ladle", "wok"
    ]

    private static let petLabels: Set<String> = [
        "tabby", "tiger cat", "Persian cat", "Siamese cat", "Egyptian cat",
        "cougar", "lion", "jaguar", "Labrador retriever", "golden retriever",
        "German shepherd", "beagle", "poodle", "Chihuahua", "Border collie",
        "dalmatian", "Doberman", "husky", "Samoyed", "hamster", "rabbit"
    ]

    private static let nightLabels: Set<String> = [
        "torch", "spotlight", "jack-o'-lantern", "Christmas stocking",
        "candle", "fireplace", "firework"
    ]

    // MARK: - Lazy model load

    private lazy var model: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodel") else {
            return nil
        }
        guard let compiled = try? MLModel(contentsOf: url),
              let vnModel = try? VNCoreMLModel(for: compiled) else {
            return nil
        }
        return vnModel
    }()

    // MARK: - Public API

    /// 픽셀 버퍼를 분류한다. 모델 로드 실패 시 nil을 반환한다.
    func classify(pixelBuffer: CVPixelBuffer) -> SceneClassificationResult? {
        guard let vnModel = model else { return nil }

        var result: SceneClassificationResult?
        let request = VNCoreMLRequest(model: vnModel) { req, _ in
            guard let obs = req.results?.first as? VNClassificationObservation else { return }
            result = SceneClassificationResult(
                sceneType: Self.sceneType(for: obs.identifier),
                rawLabel: obs.identifier,
                confidence: Double(obs.confidence)
            )
        }
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        return result
    }

    // MARK: - Private label -> SceneType

    private static func sceneType(for label: String) -> SceneType {
        let lower = label.lowercased()
        if portraitLabels.contains(lower) { return .portrait }
        if landscapeLabels.contains(lower) { return .landscape }
        if cityStreetLabels.contains(lower) { return .cityStreet }
        if foodLabels.contains(lower) { return .food }
        if petLabels.contains(lower) { return .pet }
        if nightLabels.contains(lower) { return .night }
        return .etc
    }
}
