//
//  LiveCoachingEngine.swift
//  LensNote
//
//  Req 1 — 라이브 코칭 델타 비교.
//  레퍼런스 ShotRecipe와 라이브 프레임 ShotRecipe를 비교하여
//  "더 멀리/더 가까이", 앵글 보정 코칭 메시지를 생성하는 순수 함수 모듈.
//

import Foundation

// MARK: - LiveCoachingDelta

/// 라이브 코칭 델타 비교 결과.
/// 각 축(coverage, angle)은 비교 불가하거나 차이가 임계값 미만이면 nil.
struct LiveCoachingDelta: Equatable {
    /// 피사체 커버리지 보정 메시지. "더 멀리" / "더 가까이" / nil.
    let coverageMessage: String?
    /// 카메라 앵글 보정 메시지. "카메라를 올려주세요" 등 / nil.
    let angleMessage: String?

    /// 배너에 우선 노출할 단일 메시지. coverage 우선.
    var primaryMessage: String? {
        coverageMessage ?? angleMessage
    }

    /// 두 축 모두 메시지가 없으면 빈 델타.
    var isEmpty: Bool {
        coverageMessage == nil && angleMessage == nil
    }
}

// MARK: - LiveCoachingEngine

/// 순수 함수 — 상태 없음. CameraViewModel이 소유하지 않고 호출만 한다.
enum LiveCoachingEngine {

    /// subjectCoverage 차이 임계값. (live - reference) 절대값이 이 값 이상일 때만 코칭.
    static let coverageThreshold: Double = 0.15

    /// 레퍼런스와 라이브 프레임의 ShotRecipe를 비교하여 코칭 델타를 생성한다.
    /// - Parameters:
    ///   - reference: 레퍼런스 사진의 ShotRecipe. nil이면 코칭 비활성 → 전체 nil 반환.
    ///   - live: 현재 라이브 프레임의 ShotRecipe.
    /// - Returns: 코칭 델타. reference가 nil이면 nil.
    ///   각 축(coverage/angle)이 비교 불가(nil)하거나 차이가 임계값 미만이면 해당 축 메시지는 nil.
    static func compare(
        reference: ShotRecipe?,
        live: ShotRecipe
    ) -> LiveCoachingDelta? {
        // Req 1.5 — 레퍼런스가 없으면 코칭 델타를 생성하지 않는다.
        guard let reference else { return nil }

        let coverageMessage = coverageDelta(reference: reference, live: live)
        let angleMessage = angleDelta(reference: reference, live: live)

        return LiveCoachingDelta(
            coverageMessage: coverageMessage,
            angleMessage: angleMessage
        )
    }

    // MARK: - Axis comparisons

    /// 커버리지 델타 메시지. (live - reference) >= +0.15 → "더 멀리", <= -0.15 → "더 가까이".
    /// Req 1.2, 1.8 — 어느 한쪽이라도 nil이면 메시지 없음.
    private static func coverageDelta(reference: ShotRecipe, live: ShotRecipe) -> String? {
        guard let refCoverage = reference.subjectCoverage,
              let liveCoverage = live.subjectCoverage else { return nil }

        let delta = liveCoverage - refCoverage
        if delta >= coverageThreshold {
            // 라이브 피사체가 레퍼런스보다 크게 잡힘 → 뒤로.
            return "더 멀리"
        } else if delta <= -coverageThreshold {
            // 라이브 피사체가 레퍼런스보다 작게 잡힘 → 다가가기.
            return "더 가까이"
        }
        return nil
    }

    /// 앵글 보정 메시지. 현재(live) 앵글을 목표(reference) 앵글로 맞추기 위한 안내.
    /// Req 1.3, 1.8 — 어느 한쪽이라도 nil이거나 동일하면 메시지 없음.
    ///
    /// 매핑(현재 → 목표):
    ///   highAngle → eyeLevel : "카메라를 내려주세요"
    ///   lowAngle  → eyeLevel : "카메라를 올려주세요"
    ///   eyeLevel  → highAngle: "카메라를 위로 올려주세요"
    ///   eyeLevel  → lowAngle : "카메라를 아래로 내려주세요"
    ///   highAngle → lowAngle : "카메라를 아래로 내려주세요"  (크게 낮춤)
    ///   lowAngle  → highAngle: "카메라를 위로 올려주세요"  (크게 높임)
    private static func angleDelta(reference: ShotRecipe, live: ShotRecipe) -> String? {
        guard let target = reference.cameraAngle,
              let current = live.cameraAngle,
              current != target else { return nil }

        switch (current, target) {
        case (.highAngle, .eyeLevel):
            return "카메라를 내려주세요"
        case (.lowAngle, .eyeLevel):
            return "카메라를 올려주세요"
        case (.eyeLevel, .highAngle):
            return "카메라를 위로 올려주세요"
        case (.eyeLevel, .lowAngle):
            return "카메라를 아래로 내려주세요"
        case (.highAngle, .lowAngle):
            return "카메라를 아래로 내려주세요"
        case (.lowAngle, .highAngle):
            return "카메라를 위로 올려주세요"
        default:
            return nil
        }
    }
}
