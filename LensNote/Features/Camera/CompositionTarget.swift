//
//  CompositionTarget.swift
//  LensNote
//
//  Created by Codex on 3/12/26.
//

import Foundation
import CoreGraphics

/// 현재 장면에서 "무엇을 대표 피사체로 볼지"를 정의한다.
/// - face: 얼굴 바운딩 박스를 기준으로 구도 평가
/// - salientObject: Vision saliency가 찾은 주목 영역 기준으로 평가
/// - none: 특정 피사체 없이 화면 전체를 기준으로 평가
enum SubjectKind {
    case face
    case salientObject
    case none
}

/// 장면별 목표 구도 프리셋.
/// 이 구조체가 "사용자가 원하는 이상적인 프레임" 역할을 한다.
struct CompositionTarget {
    /// UI에 노출할 프리셋 이름.
    let name: String
    /// 어떤 씬 프리셋에서 만들어졌는지 기록용 메타데이터.
    let sceneType: SceneType
    /// 어떤 종류의 피사체를 중심으로 평가할지.
    let subjectKind: SubjectKind
    /// 피사체 중심 X가 들어오길 원하는 범위(정규화 0~1).
    let targetX: ClosedRange<Double>
    /// 피사체 중심 Y가 들어오길 원하는 범위(정규화 0~1).
    let targetY: ClosedRange<Double>
    /// 피사체 크기 목표 범위. 장면에 따라 필요 없으면 nil.
    let targetSize: ClosedRange<Double>?
    /// 허용 가능한 수평/롤 오차.
    let allowedRoll: Double
    /// 얼굴 기반 구도에서 머리 위 여백 범위. 필요 없으면 nil.
    let preferredHeadroom: ClosedRange<Double>?
    /// 풍경/도시처럼 1/3 구도를 적극 유도할지 여부.
    let prefersRuleOfThirds: Bool

    /// 오버레이로 보여줄 목표 프레임의 정규화 사각형.
    let overlayRect: CGRect
}

/// 한 번에 사용자에게 안내할 대표 보정 동작.
/// 평가 결과에서 가장 중요한 수정 한 가지를 선택해 메시지로 바꾼다.
enum GuidanceCorrection: Equatable {
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case moveCloser
    case moveFarther
    case levelHorizon
    case holdSteady
    case brightenScene
    case reduceHighlights
    case findSubject
    case adjustHeadroom
    case none

    /// UI에 바로 표시할 짧은 안내 문구.
    var message: String {
        switch self {
        case .moveLeft:
            return "조금 더 왼쪽으로"
        case .moveRight:
            return "조금 더 오른쪽으로"
        case .moveUp:
            return "조금 더 위로"
        case .moveDown:
            return "조금 더 아래로"
        case .moveCloser:
            return "조금 더 가까이"
        case .moveFarther:
            return "조금 더 멀리"
        case .levelHorizon:
            return "수평이 기울었어요. 화면의 수평선을 맞춰보세요."
        case .holdSteady:
            return "손떨림이 감지돼요. 잠시 멈춘 뒤 촬영해보세요."
        case .brightenScene:
            return "조명이 부족해요. 조금 더 밝은 방향으로 이동해보세요."
        case .reduceHighlights:
            return "노출이 높아요. 밝은 영역을 화면 밖으로 조금 이동해보세요."
        case .findSubject:
            return "피사체가 화면 안에 들어오도록 맞춰주세요."
        case .adjustHeadroom:
            return "머리 위 여백을 조금만 더 맞춰보세요."
        case .none:
            return "좋아요! 지금 구도 유지"
        }
    }
}

/// 현재 프레임이 목표 구도와 얼마나 가까운지 정량화한 결과.
struct CompositionEvaluation {
    /// 지금 바로 촬영해도 되는 수준인지.
    let isAcceptable: Bool
    /// 전체 품질 점수(0~1).
    let overallScore: Double
    /// 좌우 위치 오차.
    let xError: Double
    /// 상하 위치 오차.
    let yError: Double
    /// 피사체 크기 오차.
    let sizeError: Double
    /// 기울기 오차.
    let rollError: Double
    /// 흔들림/불안정성 오차.
    let stabilityError: Double
    /// 사용자에게 우선 안내할 보정 항목.
    let primaryCorrection: GuidanceCorrection
    /// 현재 평가에 사용한 목표 프리셋.
    let target: CompositionTarget
}

/// 현재 카메라 프리뷰에 그릴 수 있는 오버레이 상태.
struct GuidanceOverlayState {
    /// 목표 구도를 시각화하는 정규화 프레임.
    let targetRect: CGRect
    /// 지금 사용자에게 보여줄 대표 보정 방향.
    let correction: GuidanceCorrection
    /// 촬영 가능 상태인지.
    let readyToCapture: Bool
    /// 어떤 프리셋이 적용 중인지 사용자에게 보여줄 이름.
    let profileName: String
}

extension CompositionTarget {
    /// 컨셉 문자열에서 더 구체적인 촬영 의도를 찾아 프리셋을 결정한다.
    static func preset(for concept: String, sceneType: SceneType) -> CompositionTarget {
        let normalized = concept.lowercased()

        if normalized.contains("셀카") || normalized.contains("selfie") {
            return portraitSelfie
        }
        if normalized.contains("전신") || normalized.contains("full body") {
            return fullBodyPortrait
        }
        if normalized.contains("반신") || normalized.contains("half body") || normalized.contains("허리") {
            return halfBodyPortrait
        }
        if normalized.contains("클로즈업") || normalized.contains("closeup") || normalized.contains("근접") {
            return closeUpPortrait
        }
        if normalized.contains("탑뷰") || normalized.contains("top view") || normalized.contains("flat lay") {
            return topDownFood
        }
        if normalized.contains("스카이라인") || normalized.contains("skyline") {
            return skylineLandscape
        }
        if normalized.contains("거리") || normalized.contains("street") || normalized.contains("도시") {
            return cityWalk
        }

        return preset(for: sceneType)
    }

    /// 컨셉에서 분류된 SceneType을 실제 목표 구도 값으로 확장한다.
    static func preset(for sceneType: SceneType) -> CompositionTarget {
        switch sceneType {
        case .portrait:
            return halfBodyPortrait
        case .pet:
            // 반려동물은 움직임이 많으므로 인물보다 허용 범위를 조금 넓힌다.
            return CompositionTarget(
                name: "Pet Focus",
                sceneType: sceneType,
                subjectKind: .face,
                targetX: 0.34...0.66,
                targetY: 0.38...0.62,
                targetSize: 0.16...0.34,
                allowedRoll: 0.10,
                preferredHeadroom: 0.06...0.22,
                prefersRuleOfThirds: false,
                overlayRect: CGRect(x: 0.22, y: 0.22, width: 0.56, height: 0.50)
            )
        case .landscape:
            return skylineLandscape
        case .cityStreet:
            return cityWalk
        case .food:
            return topDownFood
        case .night:
            // 야경은 엄격한 수평 유지와 약한 1/3 구도를 같이 사용한다.
            return CompositionTarget(
                name: "Night Street",
                sceneType: sceneType,
                subjectKind: .salientObject,
                targetX: 0.30...0.70,
                targetY: 0.30...0.70,
                targetSize: nil,
                allowedRoll: 0.08,
                preferredHeadroom: nil,
                prefersRuleOfThirds: true,
                overlayRect: CGRect(x: 0.16, y: 0.20, width: 0.68, height: 0.48)
            )
        case .etc:
            // 기본 프리셋은 너무 공격적이지 않은 중립 범위를 사용한다.
            return CompositionTarget(
                name: "Balanced Frame",
                sceneType: sceneType,
                subjectKind: .salientObject,
                targetX: 0.35...0.65,
                targetY: 0.35...0.65,
                targetSize: nil,
                allowedRoll: 0.09,
                preferredHeadroom: nil,
                prefersRuleOfThirds: false,
                overlayRect: CGRect(x: 0.24, y: 0.20, width: 0.52, height: 0.52)
            )
        }
    }

    private static let portraitSelfie = CompositionTarget(
        name: "Selfie Close",
        sceneType: .portrait,
        subjectKind: .face,
        targetX: 0.40...0.60,
        targetY: 0.38...0.54,
        targetSize: 0.26...0.42,
        allowedRoll: 0.07,
        preferredHeadroom: 0.08...0.18,
        prefersRuleOfThirds: false,
        overlayRect: CGRect(x: 0.27, y: 0.16, width: 0.46, height: 0.50)
    )

    private static let halfBodyPortrait = CompositionTarget(
        name: "Portrait Half",
        sceneType: .portrait,
        subjectKind: .face,
        targetX: 0.38...0.62,
        targetY: 0.42...0.60,
        targetSize: 0.20...0.38,
        allowedRoll: 0.08,
        preferredHeadroom: 0.08...0.20,
        prefersRuleOfThirds: false,
        overlayRect: CGRect(x: 0.24, y: 0.18, width: 0.52, height: 0.58)
    )

    private static let fullBodyPortrait = CompositionTarget(
        name: "Portrait Full",
        sceneType: .portrait,
        subjectKind: .face,
        targetX: 0.42...0.58,
        targetY: 0.46...0.62,
        targetSize: 0.10...0.20,
        allowedRoll: 0.08,
        preferredHeadroom: 0.10...0.24,
        prefersRuleOfThirds: false,
        overlayRect: CGRect(x: 0.30, y: 0.10, width: 0.40, height: 0.74)
    )

    private static let closeUpPortrait = CompositionTarget(
        name: "Portrait Close",
        sceneType: .portrait,
        subjectKind: .face,
        targetX: 0.40...0.60,
        targetY: 0.40...0.56,
        targetSize: 0.30...0.48,
        allowedRoll: 0.07,
        preferredHeadroom: 0.06...0.16,
        prefersRuleOfThirds: false,
        overlayRect: CGRect(x: 0.26, y: 0.14, width: 0.48, height: 0.54)
    )

    private static let topDownFood = CompositionTarget(
        name: "Food Top View",
        sceneType: .food,
        subjectKind: .salientObject,
        targetX: 0.42...0.58,
        targetY: 0.40...0.60,
        targetSize: 0.28...0.62,
        allowedRoll: 0.06,
        preferredHeadroom: nil,
        prefersRuleOfThirds: false,
        overlayRect: CGRect(x: 0.20, y: 0.20, width: 0.60, height: 0.60)
    )

    private static let skylineLandscape = CompositionTarget(
        name: "Landscape Wide",
        sceneType: .landscape,
        subjectKind: .salientObject,
        targetX: 0.28...0.72,
        targetY: 0.34...0.62,
        targetSize: nil,
        allowedRoll: 0.05,
        preferredHeadroom: nil,
        prefersRuleOfThirds: true,
        overlayRect: CGRect(x: 0.12, y: 0.24, width: 0.76, height: 0.36)
    )

    private static let cityWalk = CompositionTarget(
        name: "City Walk",
        sceneType: .cityStreet,
        subjectKind: .salientObject,
        targetX: 0.25...0.75,
        targetY: 0.28...0.70,
        targetSize: nil,
        allowedRoll: 0.06,
        preferredHeadroom: nil,
        prefersRuleOfThirds: true,
        overlayRect: CGRect(x: 0.16, y: 0.18, width: 0.68, height: 0.48)
    )
}
