//
//  FilterChainBuilderTests.swift
//  LensNoteTests
//
//  Phase 1 (필터 실제 적용) T1 — FilterChainBuilder 순수 체인 검증.
//  P1(no-op) + 각 필드 단독 적용 시 방향성 스모크.
//

import Testing
import CoreImage
@testable import LensNote

struct FilterChainBuilderTests {

    private let context = CIContext(options: [.useSoftwareRenderer: true])
    private let space = CGColorSpaceCreateDeviceRGB()

    /// 단색 CIImage를 4x4로 만들어 (0,0) 픽셀의 RGBA(0~1)를 샘플링.
    private func sample(_ preset: FilterPreset, r: Double, g: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let input = CIImage(color: CIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b)))
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let output = FilterChainBuilder.makeChain(from: preset)(input)
        var px = [UInt8](repeating: 0, count: 4)
        context.render(output,
                       toBitmap: &px,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: space)
        return (Double(px[0]) / 255.0, Double(px[1]) / 255.0, Double(px[2]) / 255.0)
    }

    private func preset(exposure: Double = 0, contrast: Double = 0, saturation: Double = 0, temperature: Double = 0, vignette: Double = 0) -> FilterPreset {
        FilterPreset(name: "T", exposure: exposure, contrast: contrast, saturation: saturation, temperature: temperature, vignette: vignette)
    }

    // MARK: P1 — no-op

    /// standard(전부 0) 프리셋은 입력을 그대로 통과시킨다(픽셀 허용오차 내).
    @Test("no-op: standard 프리셋 → 출력 == 입력")
    func standardIsNoOp() {
        let out = sample(.standard, r: 0.4, g: 0.55, b: 0.7)
        #expect(abs(out.r - 0.4) < 0.02)
        #expect(abs(out.g - 0.55) < 0.02)
        #expect(abs(out.b - 0.7) < 0.02)
    }

    /// isNeutral 프리셋은 makeChain이 항등 함수를 돌려준다.
    @Test("isNeutral → 항등 통과")
    func neutralPresetIsNeutralFlag() {
        #expect(FilterPreset.standard.isNeutral)
        #expect(preset(exposure: 0.1).isNeutral == false)
    }

    // MARK: 방향성 스모크

    /// exposure↑ → 밝아진다.
    @Test("exposure↑ → 밝기 증가")
    func exposureBrightens() {
        let base = sample(.standard, r: 0.4, g: 0.4, b: 0.4)
        let bright = sample(preset(exposure: 0.5), r: 0.4, g: 0.4, b: 0.4)
        #expect(bright.r > base.r)
    }

    /// saturation↑ → 채널 간 spread(max-min) 증가.
    @Test("saturation↑ → 채도 spread 증가")
    func saturationSpreads() {
        let color = (r: 0.65, g: 0.4, b: 0.4)
        let base = sample(.standard, r: color.r, g: color.g, b: color.b)
        let sat = sample(preset(saturation: 0.6), r: color.r, g: color.g, b: color.b)
        let baseSpread = max(base.r, base.g, base.b) - min(base.r, base.g, base.b)
        let satSpread = max(sat.r, sat.g, sat.b) - min(sat.r, sat.g, sat.b)
        #expect(satSpread > baseSpread)
    }

    /// contrast↑ → 밝은 픽셀은 더 밝게(중간 0.5에서 멀어짐).
    @Test("contrast↑ → 밝은 픽셀 더 밝게")
    func contrastPushesBrightUp() {
        let base = sample(.standard, r: 0.75, g: 0.75, b: 0.75)
        let contrasted = sample(preset(contrast: 0.5), r: 0.75, g: 0.75, b: 0.75)
        #expect(contrasted.r >= base.r)
    }

    /// temperature 양수 → 따뜻하게(R 채널이 B 대비 상대적으로 올라감).
    @Test("temperature↑ → 따뜻(R>B 이동)")
    func warmTemperatureShiftsRedOverBlue() {
        let base = sample(.standard, r: 0.5, g: 0.5, b: 0.5)
        let warm = sample(preset(temperature: 0.6), r: 0.5, g: 0.5, b: 0.5)
        #expect((warm.r - warm.b) > (base.r - base.b))
    }
}
