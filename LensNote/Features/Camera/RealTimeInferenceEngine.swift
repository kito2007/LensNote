//
//  RealTimeInferenceEngine.swift
//  LensNote
//
//  Created by LensNote Engineer on 2026-04-06.
//

import Foundation
import CoreVideo

/// CoreML 두 모델(MobileNetV2 + DeepLabV3)을 스로틀링하여 실시간 추론하는 엔진.
/// nonisolated(unsafe) — sampleBufferQueue에서 직접 호출한다.
final class RealTimeInferenceEngine: @unchecked Sendable {

    // MARK: - Dependencies

    private var mobileNetService = MobileNetV2Service()
    private var deepLabService = DeepLabV3Service()

    // MARK: - Scheduler

    /// CoreML 추론은 Vision보다 무거우므로 baseInterval을 0.5초로 설정한다.
    /// 디바이스 발열(thermalState)에 따라 fair/serious/critical 단계에서 점진적으로 늘어난다.
    private var lastRunTime: Date = .distantPast
    private let baseInterval: TimeInterval = 0.5

    // MARK: - Public API

    /// 픽셀 버퍼를 분석한다.
    /// - 스케줄러가 실행 주기를 아직 안 지났으면 nil을 반환한다.
    /// - 디바이스 thermalState가 critical이면 추론 자체를 건너뛴다.
    /// - 모델 로드/추론 실패 시 nil을 반환한다 (크래시 없음).
    func analyze(pixelBuffer: CVPixelBuffer) -> AIInferenceOutput? {
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical { return nil }

        let now = Date()
        guard now.timeIntervalSince(lastRunTime) >= currentInterval(for: thermalState) else { return nil }
        lastRunTime = now

        let sceneResult = mobileNetService.classify(pixelBuffer: pixelBuffer)
        let segResult = deepLabService.segment(pixelBuffer: pixelBuffer)

        // 두 모델 모두 실패한 경우 nil 반환
        if sceneResult == nil && segResult == nil { return nil }

        return AIInferenceAggregator.aggregate(scene: sceneResult, segmentation: segResult)
    }

    // MARK: - Thermal Adaptation

    /// 발열 상태별 추론 간격을 반환한다.
    /// nominal: 0.5s, fair: 0.8s, serious: 1.4s — critical은 호출되지 않음(상위에서 차단).
    private func currentInterval(for state: ProcessInfo.ThermalState) -> TimeInterval {
        switch state {
        case .nominal: return baseInterval
        case .fair:    return baseInterval * 1.6
        case .serious: return baseInterval * 2.8
        case .critical: return baseInterval * 4.0
        @unknown default: return baseInterval
        }
    }
}
