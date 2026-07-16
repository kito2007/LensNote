//
//  FilterChainBuilder.swift
//  LensNote
//
//  Phase 1 (필터 실제 적용) — FilterPreset 5개 필드를 Core Image 체인으로 변환.
//  프리뷰 경로(Path B)와 저장 경로(Path A)가 반드시 이 빌더 하나만 사용해 WYSIWYG를 보장한다(R3).
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// FilterPreset → CIImage 변환 체인을 만드는 순수 빌더. 상태 없음, 테스트 가능.
enum FilterChainBuilder {

    // MARK: 캘리브레이션 상수 (레퍼런스 추출값과 시각적으로 round-trip 되도록 튜닝 대상)
    /// exposure(-1~1) → CIExposureAdjust inputEV 스케일.
    static let evScale: Double = 2.0
    /// temperature(-1~1) → 중립 6500K 기준 목표 색온도 이동폭(K). 양수=따뜻.
    static let temperatureScale: Double = 3000.0
    /// vignette(0~1) → CIVignette inputIntensity 스케일.
    static let vignetteScale: Double = 1.5
    /// 중립 색온도(K).
    static let neutralTemperature: Double = 6500.0
    static let vignetteRadius: Double = 2.0

    /// 프리셋에 대응하는 이미지 변환 함수를 반환한다.
    /// 프리셋이 중립(전부 0)이면 입력을 그대로 통과시키는 항등 함수(R5).
    static func makeChain(from preset: FilterPreset) -> (CIImage) -> CIImage {
        guard !preset.isNeutral else { return { $0 } }

        return { input in
            var image = input

            // 1) 노출
            if preset.exposure != 0 {
                let f = CIFilter.exposureAdjust()
                f.inputImage = image
                f.ev = Float(preset.exposure * evScale)
                image = f.outputImage ?? image
            }

            // 2) 색온도 (중립 6500K → 목표 색온도)
            // CITemperatureAndTint는 targetNeutral 색온도를 올리면 이미지가 오히려 차가워진다(보정 방향이 반대).
            // preset.temperature 양수=따뜻이 되도록 목표 색온도를 낮춘다.
            if preset.temperature != 0 {
                let f = CIFilter.temperatureAndTint()
                f.inputImage = image
                f.neutral = CIVector(x: CGFloat(neutralTemperature), y: 0)
                f.targetNeutral = CIVector(x: CGFloat(neutralTemperature - preset.temperature * temperatureScale), y: 0)
                image = f.outputImage ?? image
            }

            // 3) 대비 + 채도 (동일 CIColorControls 인스턴스)
            if preset.contrast != 0 || preset.saturation != 0 {
                let f = CIFilter.colorControls()
                f.inputImage = image
                f.contrast = Float(1.0 + preset.contrast)
                f.saturation = Float(1.0 + preset.saturation)
                f.brightness = 0
                image = f.outputImage ?? image
            }

            // 4) 비네트
            if preset.vignette != 0 {
                let f = CIFilter.vignette()
                f.inputImage = image
                f.intensity = Float(preset.vignette * vignetteScale)
                f.radius = Float(vignetteRadius)
                image = f.outputImage ?? image
            }

            // CIVignette/TemperatureAndTint 등이 extent를 확장할 수 있어 원본 프레임으로 크롭.
            return image.cropped(to: input.extent)
        }
    }
}
