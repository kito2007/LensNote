//
//  AIInferenceAggregator.swift
//  LensNote
//
//  Created by LensNote Engineer on 2026-04-06.
//

import Foundation
import CoreGraphics

/// 두 CoreML 모델의 결과를 합성한 최종 AI 추론 출력.
struct AIInferenceOutput {
    /// 최종 장면 유형 (MobileNetV2 + DeepLabV3 합의).
    let sceneType: SceneType
    /// UI 표시용 짧은 레이블 (영어 대문자).
    let sceneLabel: String
    /// 종합 점수 (0~1). confidence 60% + 구도 적합도 40%.
    let inferenceScore: Double
    /// 피사체 바운딩 박스 (정규화 좌표 0~1). 없으면 nil.
    let subjectBoundingBox: CGRect?
    /// 피사체가 차지하는 면적 비율 (0~1).
    let subjectCoverage: Double
    /// 구도 힌트 문구. 문제 없으면 nil.
    let guidanceHint: String?
}

/// MobileNetV2 결과와 DeepLabV3 결과를 합산해 AIInferenceOutput을 만드는 순수 함수 집합.
/// 상태 없음 — 모든 메서드가 static.
enum AIInferenceAggregator {

    /// person 클래스(15)가 전체 면적의 이 비율을 초과하면 portrait로 강제 오버라이드.
    private static let portraitCoverageThreshold: Double = 0.05
    /// 삼등분선 편차가 이 값을 초과하면 구도 힌트를 표시한다.
    private static let ruleOfThirdsOffsetThreshold: Double = 0.12

    static func aggregate(
        scene: SceneClassificationResult?,
        segmentation: SegmentationResult?
    ) -> AIInferenceOutput {

        // 1. SceneType 합의
        var resolvedScene = scene?.sceneType ?? .etc
        let confidence = scene?.confidence ?? 0.0

        if let seg = segmentation {
            // DeepLabV3 person(index 15) 비율이 임계값 초과 시 portrait로 오버라이드
            let isPersonDominant = seg.dominantClass == 15 && seg.subjectCoverage >= portraitCoverageThreshold
            if isPersonDominant {
                resolvedScene = .portrait
            }
        }

        // 2. 구도 점수 계산
        let compositionScore: Double
        if let seg = segmentation, seg.subjectBoundingBox != nil {
            // 삼등분선 편차를 구도 점수로 변환: 편차 0 -> 점수 1, 편차 0.5 -> 점수 0
            let offsetMag = sqrt(
                pow(seg.ruleOfThirdsOffset.x, 2) + pow(seg.ruleOfThirdsOffset.y, 2)
            )
            compositionScore = max(0, 1.0 - offsetMag * 2.0)
        } else {
            compositionScore = 0.5 // 피사체 없으면 중립
        }

        let inferenceScore = confidence * 0.6 + compositionScore * 0.4

        // 3. 구도 힌트 문구
        var guidanceHint: String?
        if let seg = segmentation, seg.subjectBoundingBox != nil {
            let ox = seg.ruleOfThirdsOffset.x
            let oy = seg.ruleOfThirdsOffset.y
            let absX = abs(ox)
            let absY = abs(oy)

            if absX > ruleOfThirdsOffsetThreshold || absY > ruleOfThirdsOffsetThreshold {
                if absX >= absY {
                    guidanceHint = ox > 0 ? "피사체를 왼쪽으로 이동해보세요." : "피사체를 오른쪽으로 이동해보세요."
                } else {
                    guidanceHint = oy > 0 ? "피사체를 위로 이동해보세요." : "피사체를 아래로 이동해보세요."
                }
            }
        }

        // 4. UI 레이블
        let sceneLabel = Self.label(for: resolvedScene, rawLabel: scene?.rawLabel)

        return AIInferenceOutput(
            sceneType: resolvedScene,
            sceneLabel: sceneLabel,
            inferenceScore: min(1.0, max(0.0, inferenceScore)),
            subjectBoundingBox: segmentation?.subjectBoundingBox,
            subjectCoverage: segmentation?.subjectCoverage ?? 0,
            guidanceHint: guidanceHint
        )
    }

    // MARK: - Private helpers

    private static func label(for sceneType: SceneType, rawLabel: String?) -> String {
        switch sceneType {
        case .portrait: return "PORTRAIT"
        case .landscape: return "LANDSCAPE"
        case .cityStreet: return "STREET"
        case .food: return "FOOD"
        case .night: return "NIGHT"
        case .pet: return "PET"
        case .etc:
            // rawLabel이 있으면 최대 10자까지 대문자로 노출
            if let raw = rawLabel, !raw.isEmpty {
                return String(raw.uppercased().prefix(10))
            }
            return "STANDARD"
        }
    }
}
