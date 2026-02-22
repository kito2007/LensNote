//
//  CameraAssistService.swift
//  LensNote
//
//  Created by Codex on 2/21/26.
//

import Foundation
import UIKit

struct CameraRecommendation {
    let title: String
    let iso: String
    let shutterSpeed: String
    let aperture: String
    let whiteBalance: String
}

protocol CameraAssistServiceProtocol {
    func recommendation(from preset: FilterPreset?, concept: String) -> CameraRecommendation
    func compositionTips(concept: String, guidance: String) -> [String]
    func analyzeReferenceImage(_ image: UIImage) -> FilterPreset
}

struct MockCameraAssistService: CameraAssistServiceProtocol {
    func recommendation(from preset: FilterPreset?, concept: String) -> CameraRecommendation {
        let normalized = concept.lowercased()
        if normalized.contains("야경") || normalized.contains("밤") {
            return CameraRecommendation(
                title: "Night Assist",
                iso: "ISO 800-3200",
                shutterSpeed: "1/30s - 1s",
                aperture: "f/2.8 - f/4",
                whiteBalance: "3500K"
            )
        }

        if normalized.contains("인물") || normalized.contains("portrait") {
            return CameraRecommendation(
                title: "Portrait Assist",
                iso: "ISO 100-400",
                shutterSpeed: "1/125s - 1/250s",
                aperture: "f/1.8 - f/2.8",
                whiteBalance: "AWB"
            )
        }

        let presetTitle = preset?.name ?? "Standard Assist"
        return CameraRecommendation(
            title: presetTitle,
            iso: "ISO 100-400",
            shutterSpeed: "1/125s",
            aperture: "f/5.6",
            whiteBalance: "AWB"
        )
    }

    func compositionTips(concept: String, guidance: String) -> [String] {
        if concept.lowercased().contains("풍경") {
            return [guidance, "수평선을 1/3 지점에 배치", "전경 요소로 깊이감 만들기"]
        }
        return [guidance, "피사체를 교차점에 배치", "배경 요소를 단순화"]
    }

    func analyzeReferenceImage(_ image: UIImage) -> FilterPreset {
        // 임시 규칙 기반 분석: 실제 CoreML 연동 전까지 레퍼런스 입력 흐름만 유지.
        let size = image.size.width * image.size.height
        if size > 3_000_000 {
            return FilterPreset(name: "Detail Boost", exposure: 0.04, contrast: 0.18, saturation: 0.08, temperature: -0.04, vignette: 0.22)
        }
        return FilterPreset(name: "Soft Mood", exposure: 0.08, contrast: 0.06, saturation: 0.04, temperature: 0.08, vignette: 0.18)
    }
}

struct CoreMLCameraAssistService: CameraAssistServiceProtocol {
    func recommendation(from preset: FilterPreset?, concept: String) -> CameraRecommendation {
        // TODO: CoreML 모델 추론 결과로 교체.
        MockCameraAssistService().recommendation(from: preset, concept: concept)
    }

    func compositionTips(concept: String, guidance: String) -> [String] {
        // TODO: Vision/CoreML 프레임 분석 결과 기반 tip 생성.
        MockCameraAssistService().compositionTips(concept: concept, guidance: guidance)
    }

    func analyzeReferenceImage(_ image: UIImage) -> FilterPreset {
        // TODO: CoreML 이미지 분석 결과를 FilterPreset으로 매핑.
        MockCameraAssistService().analyzeReferenceImage(image)
    }
}
