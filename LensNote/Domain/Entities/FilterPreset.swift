//
//  FilterPreset.swift
//  LensNote
//
//  Phase 1 (필터 실제 적용) — CameraViewModel에 있던 정의를 도메인으로 승격.
//  뷰 미리보기·뷰모델 적용·저장 파이프라인이 동일한 단일 소스를 공유한다.
//

import Foundation

/// 레퍼런스/컨셉에서 추출한 색보정 프리셋. 값은 0을 중심으로 대략 -1~1.
struct FilterPreset: Equatable {
    let name: String
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let temperature: Double
    let vignette: Double
}

extension FilterPreset {
    static let standard = FilterPreset(name: "Standard", exposure: 0, contrast: 0, saturation: 0, temperature: 0, vignette: 0)

    /// 프리셋이 색보정을 전혀 하지 않는(전부 0) 상태인지 여부. no-op 통과 판단용(R5).
    var isNeutral: Bool {
        exposure == 0 && contrast == 0 && saturation == 0 && temperature == 0 && vignette == 0
    }

    /// 컨셉 문자열에 기반한 필터 프리셋을 결정한다.
    /// 뷰 미리보기와 뷰모델 적용이 동일한 룰을 공유하도록 단일 소스로 유지.
    static func forConcept(_ text: String) -> FilterPreset {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return .standard }

        if keyword.contains("무드") || keyword.contains("시네마") || keyword.contains("cinematic") {
            return FilterPreset(name: "Cinematic", exposure: -0.1, contrast: 0.25, saturation: -0.05, temperature: -0.05, vignette: 0.4)
        }
        if keyword.contains("빈티지") || keyword.contains("필름") || keyword.contains("vintage") {
            return FilterPreset(name: "Vintage", exposure: 0.05, contrast: -0.1, saturation: -0.15, temperature: 0.15, vignette: 0.35)
        }
        if keyword.contains("야경") || keyword.contains("밤") || keyword.contains("night") {
            return FilterPreset(name: "Night Mood", exposure: -0.15, contrast: 0.30, saturation: -0.10, temperature: -0.10, vignette: 0.45)
        }
        if keyword.contains("인물") || keyword.contains("portrait") {
            return FilterPreset(name: "Portrait", exposure: 0.05, contrast: 0.08, saturation: 0.12, temperature: 0.12, vignette: 0.15)
        }
        if keyword.contains("풍경") || keyword.contains("landscape") {
            return FilterPreset(name: "Landscape", exposure: 0.02, contrast: 0.18, saturation: 0.20, temperature: -0.02, vignette: 0.10)
        }
        if keyword.contains("따뜻") || keyword.contains("warm") {
            return FilterPreset(name: "Warm", exposure: 0.1, contrast: 0.1, saturation: 0.1, temperature: 0.2, vignette: 0.2)
        }
        if keyword.contains("차가") || keyword.contains("cool") {
            return FilterPreset(name: "Cool", exposure: 0.0, contrast: 0.1, saturation: 0.05, temperature: -0.2, vignette: 0.15)
        }
        return .standard
    }
}
