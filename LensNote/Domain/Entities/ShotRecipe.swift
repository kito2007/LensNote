//
//  ShotRecipe.swift
//  LensNote
//
//  Created by LensNote Engineer on 2026-05-09.
//

import Foundation
import CoreGraphics

// MARK: - Supporting enums

/// 피사체의 프레임 내 수직 위치.
enum VerticalPosition: String, Codable, Equatable {
    case top, middle, bottom
}

/// 카메라 앵글 추정값.
enum CameraAngle: String, Codable, Equatable {
    case highAngle, eyeLevel, lowAngle
}

/// 피사체의 시선 방향.
enum GazeDirection: String, Codable, Equatable {
    case toCamera, awayFromCamera, unknown
}

/// 주요 사진 스타일 라벨.
enum ShotStyle: String, Codable, Equatable {
    case aerialSelfie, mirrorSelfie, footShot, backView, unknown
    /// 정면 응시 eye-level 셀피 (인스타 가장 일반적인 케이스).
    case classicSelfie
    /// 광각 셀피 — 본인 + 배경을 함께 담은 와이드 구도 (coverage 10~40%, focal ≤ 28mm 또는 미상).
    case wideSelfie
    /// 풍경/배경 중심 — 사람 없거나 피사체 coverage 5% 미만.
    case landscape
    /// 근접/매크로 — 피사체가 화면의 65% 이상을 차지하는 경우.
    case closeUp
}

/// ShotStyle 분류 확신도.
enum ShotStyleConfidence: String, Codable, Equatable {
    case high, medium, low
}

// MARK: - CGRect Codable shim

/// CGRect는 기본 Codable을 제공하지 않으므로 저장 가능한 중간 구조체를 둔다.
struct CodableRect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - ShotRecipe

/// 레퍼런스 사진 한 장에서 추출한 촬영 레시피 전체.
/// EXIF, Vision Human Rectangles, Face Landmarks, DeepLabV3 person mask 를 합성한 결과물.
struct ShotRecipe: Codable, Equatable {

    // MARK: EXIF

    /// 35mm 환산 초점 거리 (mm). EXIF 없으면 nil.
    let focalLength35mm: Double?
    /// 조리개 값 (f-number). EXIF 없으면 nil.
    let aperture: Double?
    /// ISO 감도. EXIF 없으면 nil.
    let iso: Int?
    /// 셔터 속도 (초). EXIF 없으면 nil.
    let shutterSpeed: Double?

    // MARK: Vision / DeepLab

    /// 피사체(사람)가 차지하는 화면 면적 비율 (0~1). 미검출 시 nil.
    let subjectCoverage: Double?
    /// 피사체의 프레임 내 수직 위치. 미검출 시 nil.
    let subjectVerticalPosition: VerticalPosition?
    /// 피사체 바운딩 박스 (정규화 좌표 0~1, top-left origin). 미검출 시 nil.
    /// CGRect 직접 Codable 불가 — CodableRect로 래핑하여 저장.
    let subjectBoundingBox: CodableRect?

    // MARK: Face geometry

    /// 카메라 앵글 추정. 얼굴 미검출 시 nil.
    let cameraAngle: CameraAngle?
    /// 피사체의 시선 방향. 얼굴 미검출 시 nil.
    let gazeDirection: GazeDirection?
    /// 얼굴 수평 회전각 (radians). 양수 = 오른쪽으로 돌림. 미검출 시 nil.
    let faceYaw: Double?
    /// 얼굴 수직 회전각 (radians). 양수 = 위를 향함. 미검출 시 nil.
    let facePitch: Double?

    // MARK: Horizon

    /// 수평선 기울기 (degrees). 현재 단계에서는 Vision fallback 없음 — 항상 nil.
    let horizonTilt: Double?

    // MARK: Classification

    /// 분류된 사진 스타일.
    let detectedStyle: ShotStyle
    /// 스타일 분류 확신도.
    let styleConfidence: ShotStyleConfidence
}
