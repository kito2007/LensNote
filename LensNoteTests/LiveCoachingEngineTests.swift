//
//  LiveCoachingEngineTests.swift
//  LensNoteTests
//
//  Req 1 — LiveCoachingEngine property tests.
//  Property 1: Coverage delta coaching message correctness (Req 1.2, 1.8)
//  Property 2: No coaching delta without reference (Req 1.5)
//

import Testing
@testable import LensNote

struct LiveCoachingEngineTests {

    // MARK: - Helpers

    /// 테스트용 최소 ShotRecipe 빌더. coverage/angle 외 축은 nil/기본값.
    private func makeRecipe(
        subjectCoverage: Double? = nil,
        cameraAngle: CameraAngle? = nil
    ) -> ShotRecipe {
        ShotRecipe(
            focalLength35mm: nil,
            aperture: nil,
            iso: nil,
            shutterSpeed: nil,
            subjectCoverage: subjectCoverage,
            subjectVerticalPosition: nil,
            subjectBoundingBox: nil,
            cameraAngle: cameraAngle,
            gazeDirection: nil,
            faceYaw: nil,
            facePitch: nil,
            horizonTilt: nil,
            detectedStyle: .unknown,
            styleConfidence: .low
        )
    }

    // MARK: - Property 1: Coverage delta coaching message correctness

    /// 랜덤 coverage 쌍 100회 — (live - reference) 부호/임계값에 따른 메시지 정확성.
    /// Validates Req 1.2, 1.8.
    @Test("Property 1: coverage delta 메시지 정확성")
    func coverageDeltaMessageCorrectness() {
        let threshold = LiveCoachingEngine.coverageThreshold
        for i in 0..<100 {
            // 결정론적이지만 두 축이 다른 값을 갖도록 i 기반 의사난수 생성.
            let ref = Double((i * 37) % 101) / 100.0
            let live = Double((i * 53 + 7) % 101) / 100.0

            let delta = LiveCoachingEngine.compare(
                reference: makeRecipe(subjectCoverage: ref),
                live: makeRecipe(subjectCoverage: live)
            )

            let diff = live - ref
            let expected: String?
            if diff >= threshold {
                expected = "더 멀리"
            } else if diff <= -threshold {
                expected = "더 가까이"
            } else {
                expected = nil
            }

            #expect(delta?.coverageMessage == expected,
                    "i=\(i) ref=\(ref) live=\(live) diff=\(diff)")
        }
    }

    /// 어느 한쪽 coverage가 nil이면 coverage 메시지 없음.
    @Test("coverage nil이면 메시지 생략")
    func coverageNilProducesNoMessage() {
        let refNil = LiveCoachingEngine.compare(
            reference: makeRecipe(subjectCoverage: nil),
            live: makeRecipe(subjectCoverage: 0.9)
        )
        #expect(refNil?.coverageMessage == nil)

        let liveNil = LiveCoachingEngine.compare(
            reference: makeRecipe(subjectCoverage: 0.1),
            live: makeRecipe(subjectCoverage: nil)
        )
        #expect(liveNil?.coverageMessage == nil)
    }

    /// 임계값 근방: 임계값보다 약간 큰 차이는 메시지 발생, 약간 작은 차이는 nil.
    /// (정확히 ±0.15 경계는 부동소수점 오차로 모호하므로 ±0.16 / ±0.14로 컷오프를 검증.)
    @Test("coverage 임계값 컷오프")
    func coverageThresholdCutoff() {
        // diff ≈ +0.16 → 더 멀리
        let farther = LiveCoachingEngine.compare(
            reference: makeRecipe(subjectCoverage: 0.20),
            live: makeRecipe(subjectCoverage: 0.36)
        )
        #expect(farther?.coverageMessage == "더 멀리")

        // diff ≈ +0.14 → 임계 미만, 메시지 없음
        let withinFar = LiveCoachingEngine.compare(
            reference: makeRecipe(subjectCoverage: 0.20),
            live: makeRecipe(subjectCoverage: 0.34)
        )
        #expect(withinFar?.coverageMessage == nil)

        // diff ≈ -0.16 → 더 가까이
        let closer = LiveCoachingEngine.compare(
            reference: makeRecipe(subjectCoverage: 0.36),
            live: makeRecipe(subjectCoverage: 0.20)
        )
        #expect(closer?.coverageMessage == "더 가까이")

        // diff ≈ -0.14 → 임계 미만, 메시지 없음
        let withinClose = LiveCoachingEngine.compare(
            reference: makeRecipe(subjectCoverage: 0.34),
            live: makeRecipe(subjectCoverage: 0.20)
        )
        #expect(withinClose?.coverageMessage == nil)
    }

    // MARK: - Property 2: No coaching delta without reference

    /// 랜덤 live ShotRecipe 100회 — reference가 nil이면 항상 nil 반환.
    /// Validates Req 1.5.
    @Test("Property 2: 레퍼런스 없으면 델타 없음")
    func noDeltaWithoutReference() {
        let angles: [CameraAngle?] = [nil, .highAngle, .eyeLevel, .lowAngle]
        for i in 0..<100 {
            let coverage: Double? = (i % 5 == 0) ? nil : Double((i * 41) % 101) / 100.0
            let angle = angles[i % angles.count]
            let live = makeRecipe(subjectCoverage: coverage, cameraAngle: angle)

            let delta = LiveCoachingEngine.compare(reference: nil, live: live)
            #expect(delta == nil, "i=\(i) coverage=\(String(describing: coverage)) angle=\(String(describing: angle))")
        }
    }

    // MARK: - Angle mapping (Req 1.3)

    @Test("앵글 매핑 — 현재→목표 보정 메시지")
    func angleMappingMessages() {
        let cases: [(current: CameraAngle, target: CameraAngle, message: String)] = [
            (.highAngle, .eyeLevel, "카메라를 내려주세요"),
            (.lowAngle, .eyeLevel, "카메라를 올려주세요"),
            (.eyeLevel, .highAngle, "카메라를 위로 올려주세요"),
            (.eyeLevel, .lowAngle, "카메라를 아래로 내려주세요"),
        ]
        for c in cases {
            let delta = LiveCoachingEngine.compare(
                reference: makeRecipe(cameraAngle: c.target),
                live: makeRecipe(cameraAngle: c.current)
            )
            #expect(delta?.angleMessage == c.message,
                    "current=\(c.current) target=\(c.target)")
        }
    }

    @Test("앵글 동일하면 메시지 없음")
    func sameAngleNoMessage() {
        let delta = LiveCoachingEngine.compare(
            reference: makeRecipe(cameraAngle: .eyeLevel),
            live: makeRecipe(cameraAngle: .eyeLevel)
        )
        #expect(delta?.angleMessage == nil)
    }

    @Test("앵글 nil이면 메시지 없음")
    func angleNilNoMessage() {
        let delta = LiveCoachingEngine.compare(
            reference: makeRecipe(cameraAngle: nil),
            live: makeRecipe(cameraAngle: .highAngle)
        )
        #expect(delta?.angleMessage == nil)
    }
}
