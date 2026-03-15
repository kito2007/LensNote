//
//  CompositionTarget.swift
//  LensNote
//
//  Created by Codex on 3/12/26.
//

import Foundation

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
}

extension CompositionTarget {
    /// 컨셉에서 분류된 SceneType을 실제 목표 구도 값으로 확장한다.
    static func preset(for sceneType: SceneType) -> CompositionTarget {
        switch sceneType {
        case .portrait:
            // 인물은 얼굴이 너무 치우치지 않고, 약간 위쪽에 오도록 설정.
            return CompositionTarget(
                sceneType: sceneType,
                subjectKind: .face,
                targetX: 0.38...0.62,
                targetY: 0.42...0.60,
                targetSize: 0.20...0.38,
                allowedRoll: 0.08,
                preferredHeadroom: 0.08...0.20,
                prefersRuleOfThirds: false
            )
        case .pet:
            // 반려동물은 움직임이 많으므로 인물보다 허용 범위를 조금 넓힌다.
            return CompositionTarget(
                sceneType: sceneType,
                subjectKind: .face,
                targetX: 0.34...0.66,
                targetY: 0.38...0.62,
                targetSize: 0.16...0.34,
                allowedRoll: 0.10,
                preferredHeadroom: 0.06...0.22,
                prefersRuleOfThirds: false
            )
        case .landscape:
            // 풍경은 수평이 더 중요하고, 중앙보다 1/3 구도 유도를 선호한다.
            return CompositionTarget(
                sceneType: sceneType,
                subjectKind: .salientObject,
                targetX: 0.28...0.72,
                targetY: 0.30...0.70,
                targetSize: nil,
                allowedRoll: 0.05,
                preferredHeadroom: nil,
                prefersRuleOfThirds: true
            )
        case .cityStreet:
            // 도시/거리는 풍경과 유사하지만 피사체 위치 허용 범위를 조금 더 넓힌다.
            return CompositionTarget(
                sceneType: sceneType,
                subjectKind: .salientObject,
                targetX: 0.25...0.75,
                targetY: 0.28...0.70,
                targetSize: nil,
                allowedRoll: 0.06,
                preferredHeadroom: nil,
                prefersRuleOfThirds: true
            )
        case .food:
            // 음식은 중앙 정렬과 적당한 크기를 더 중요하게 본다.
            return CompositionTarget(
                sceneType: sceneType,
                subjectKind: .salientObject,
                targetX: 0.38...0.62,
                targetY: 0.38...0.62,
                targetSize: 0.22...0.60,
                allowedRoll: 0.09,
                preferredHeadroom: nil,
                prefersRuleOfThirds: false
            )
        case .night:
            // 야경은 엄격한 수평 유지와 약한 1/3 구도를 같이 사용한다.
            return CompositionTarget(
                sceneType: sceneType,
                subjectKind: .salientObject,
                targetX: 0.30...0.70,
                targetY: 0.30...0.70,
                targetSize: nil,
                allowedRoll: 0.08,
                preferredHeadroom: nil,
                prefersRuleOfThirds: true
            )
        case .etc:
            // 기본 프리셋은 너무 공격적이지 않은 중립 범위를 사용한다.
            return CompositionTarget(
                sceneType: sceneType,
                subjectKind: .salientObject,
                targetX: 0.35...0.65,
                targetY: 0.35...0.65,
                targetSize: nil,
                allowedRoll: 0.09,
                preferredHeadroom: nil,
                prefersRuleOfThirds: false
            )
        }
    }
}
