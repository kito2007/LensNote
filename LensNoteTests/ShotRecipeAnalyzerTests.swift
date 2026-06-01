//
//  ShotRecipeAnalyzerTests.swift
//  LensNoteTests
//
//  Req 9.2 — ShotRecipeAnalyzer.classifyStyle 라벨링 룰 검증 (최소 4종).
//

import Testing
@testable import LensNote

struct ShotRecipeAnalyzerTests {

    /// aerialSelfie — highAngle + 카메라 응시 + 커버리지 25% 이상.
    @Test("aerialSelfie 분류")
    func classifiesAerialSelfie() {
        let (style, _) = ShotRecipeAnalyzer.classifyStyle(
            cameraAngle: .highAngle,
            gazeDirection: .toCamera,
            subjectCoverage: 0.30,
            subjectBBox: nil,
            faceYaw: 0.1,
            facePitch: -0.4,
            focalLength35mm: 24.0
        )
        #expect(style == .aerialSelfie)
    }

    /// mirrorSelfie — eyeLevel + 카메라 외면 + 커버리지 15% 이상.
    @Test("mirrorSelfie 분류")
    func classifiesMirrorSelfie() {
        let (style, _) = ShotRecipeAnalyzer.classifyStyle(
            cameraAngle: .eyeLevel,
            gazeDirection: .awayFromCamera,
            subjectCoverage: 0.20,
            subjectBBox: nil,
            faceYaw: 0.6,
            facePitch: 0.0,
            focalLength35mm: 35.0
        )
        #expect(style == .mirrorSelfie)
    }

    /// landscape — 피사체 커버리지 10% 미만.
    @Test("landscape 분류")
    func classifiesLandscape() {
        let (style, _) = ShotRecipeAnalyzer.classifyStyle(
            cameraAngle: nil,
            gazeDirection: nil,
            subjectCoverage: 0.05,
            subjectBBox: nil,
            faceYaw: nil,
            facePitch: nil,
            focalLength35mm: 50.0
        )
        #expect(style == .landscape)
    }

    /// unknown — 어떤 룰에도 해당하지 않는 조합.
    /// eyeLevel + gaze unknown + 커버리지 50% + 얼굴 yaw 존재(backView 회피).
    @Test("unknown 분류")
    func classifiesUnknown() {
        let (style, _) = ShotRecipeAnalyzer.classifyStyle(
            cameraAngle: .eyeLevel,
            gazeDirection: .unknown,
            subjectCoverage: 0.50,
            subjectBBox: nil,
            faceYaw: 0.5,
            facePitch: nil,
            focalLength35mm: nil
        )
        #expect(style == .unknown)
    }
}
