//
//  AIInferenceAggregatorTests.swift
//  LensNoteTests
//
//  Req 9.1 — AIInferenceAggregator.aggregate inferenceScore 계산 검증.
//

import Testing
import CoreGraphics
@testable import LensNote

struct AIInferenceAggregatorTests {

    /// (a) confidence=0, compositionScore=0 → inferenceScore 0.0
    /// compositionScore 0은 bbox가 있고 삼등분선 편차 크기가 0.5 이상일 때 발생.
    @Test("confidence 0 + composition 0 → score 0.0")
    func zeroInputsProduceZeroScore() {
        let scene = SceneClassificationResult(sceneType: .etc, rawLabel: "", confidence: 0.0)
        let seg = SegmentationResult(
            dominantClass: 0,
            dominantClassName: "background",
            subjectBoundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.1),
            subjectCoverage: 0.1,
            ruleOfThirdsOffset: CGPoint(x: 0.5, y: 0.0), // |offset|=0.5 → compositionScore 0
            personBoundingBox: nil,
            personCoverage: 0
        )

        let output = AIInferenceAggregator.aggregate(scene: scene, segmentation: seg)

        #expect(abs(output.inferenceScore - 0.0) < 0.0001)
    }

    /// (b) confidence=1.0, compositionScore=1.0 → inferenceScore 1.0
    @Test("confidence 1.0 + composition 1.0 → score 1.0")
    func maxInputsProduceMaxScore() {
        let scene = SceneClassificationResult(sceneType: .landscape, rawLabel: "scene", confidence: 1.0)
        let seg = SegmentationResult(
            dominantClass: 0,
            dominantClassName: "background",
            subjectBoundingBox: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
            subjectCoverage: 0.2,
            ruleOfThirdsOffset: .zero, // 편차 0 → compositionScore 1.0
            personBoundingBox: nil,
            personCoverage: 0
        )

        let output = AIInferenceAggregator.aggregate(scene: scene, segmentation: seg)

        #expect(abs(output.inferenceScore - 1.0) < 0.0001)
    }

    /// (c) scene=nil, segmentation=nil → 크래시 없이 기본값.
    /// confidence 0 + 피사체 없음(compositionScore 0.5) → score 0.2, sceneType .etc.
    @Test("nil/nil 입력 → 크래시 없이 기본값")
    func nilInputsReturnDefaults() {
        let output = AIInferenceAggregator.aggregate(scene: nil, segmentation: nil)

        #expect(output.sceneType == .etc)
        #expect(output.sceneLabel == "STANDARD")
        #expect(output.subjectBoundingBox == nil)
        #expect(abs(output.subjectCoverage - 0.0) < 0.0001)
        #expect(abs(output.inferenceScore - 0.2) < 0.0001)
    }
}
