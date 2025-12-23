//
//  StyleProfile.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation

/// 카메라/필터에 적용할 스타일 프로필
/// 25/12/23 기준, 옵션 확정 x -> 어시스트 모델이 출력해주는 방향으로 수정할 예정
public struct StyleProfile: Codable, Equatable, Sendable {
    public let id: String
    public let sceneType: SceneType

    /// -1.0 ~ +1.0 자동 노출 대비
    public let exposureBias: Double

    /// -1.0 ~ +1.0 후처리 밝기
    public let brightness: Double

    /// -1.0(차갑게) ~ +1.0(따뜻하게)
    public let temperature: Double

    /// -1.0(초록) ~ +1.0(마젠타)
    public let tint: Double

    /// -1.0 ~ +1.0
    public let contrast: Double

    /// -1.0 ~ +1.0
    public let saturation: Double

    /// 0 ~ 1
    public let vignetteLevel: Double

    /// 0 ~ 1
    public let grainLevel: Double

    public let filterStyle: FilterStyle

    public init(
        id: String = UUID().uuidString,
        sceneType: SceneType,
        exposureBias: Double,
        brightness: Double,
        temperature: Double,
        tint: Double,
        contrast: Double,
        saturation: Double,
        vignetteLevel: Double,
        grainLevel: Double,
        filterStyle: FilterStyle
    ) {
        self.id = id
        self.sceneType = sceneType
        self.exposureBias = exposureBias
        self.brightness = brightness
        self.temperature = temperature
        self.tint = tint
        self.contrast = contrast
        self.saturation = saturation
        self.vignetteLevel = vignetteLevel
        self.grainLevel = grainLevel
        self.filterStyle = filterStyle
    }
}
