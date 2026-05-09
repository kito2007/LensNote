//
//  ShotRecipeAnalyzer.swift
//  LensNote
//
//  Created by LensNote Engineer on 2026-05-09.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import ImageIO
import Vision

/// 레퍼런스 사진(Data)에서 ShotRecipe를 추출하는 서비스.
/// - EXIF, VNDetectHumanRectanglesRequest, VNDetectFaceLandmarksRequest, DeepLabV3 person mask 를 병렬·독립 실행한다.
/// - 한 단계가 실패해도 나머지 결과로 ShotRecipe를 완성한다.
/// - @MainActor 금지 — 백그라운드 Task에서 호출된다.
final class ShotRecipeAnalyzer {

    // MARK: - DeepLabV3 dependency

    private var deepLabService = DeepLabV3Service()

    // MARK: - Public API

    /// 이미지 데이터를 분석하여 ShotRecipe를 반환한다. 어떤 입력이 들어와도 크래시 없이 반환.
    func analyze(imageData: Data) async -> ShotRecipe {
        // 단계 A — EXIF (동기, 가벼움)
        let exif = extractEXIF(from: imageData)

        // UIImage → CVPixelBuffer 변환 (단계 B, C, D 공통 입력)
        let pixelBuffer = makePixelBuffer(from: imageData)

        // 단계 B — VNDetectHumanRectanglesRequest
        let humanResult = pixelBuffer.flatMap { detectHuman(in: $0) }

        // 단계 C — VNDetectFaceLandmarksRequest
        let faceResult = pixelBuffer.flatMap { detectFace(in: $0) }

        // 단계 D — DeepLabV3 person mask
        let segResult = pixelBuffer.flatMap { deepLabService.segment(pixelBuffer: $0) }

        // 피사체 커버리지 — DeepLabV3(person) 우선, fallback: humanBbox 면적
        let subjectCoverage: Double?
        if let seg = segResult, seg.dominantClass == 15 {
            subjectCoverage = seg.subjectCoverage
        } else if let human = humanResult {
            subjectCoverage = Double(human.boundingBox.width * human.boundingBox.height)
        } else {
            subjectCoverage = nil
        }

        // 피사체 바운딩 박스 (Vision = bottom-left origin → top-left 변환)
        let subjectBBox: CodableRect?
        if let seg = segResult, seg.dominantClass == 15, let segBox = seg.subjectBoundingBox {
            // DeepLabV3 박스는 postprocess에서 이미 top-left origin (row/col 순회 기준)
            subjectBBox = CodableRect(segBox)
        } else if let human = humanResult {
            // Vision bounding box는 bottom-left origin → flip Y
            let vb = human.boundingBox
            let flipped = CGRect(x: vb.origin.x,
                                 y: 1.0 - vb.origin.y - vb.height,
                                 width: vb.width,
                                 height: vb.height)
            subjectBBox = CodableRect(flipped)
        } else {
            subjectBBox = nil
        }

        // 피사체 수직 위치 (top-left origin 기준 midY)
        let subjectVertPos: VerticalPosition?
        if let box = subjectBBox {
            let midY = box.y + box.height / 2.0
            if midY < 0.4 {
                subjectVertPos = .top
            } else if midY > 0.65 {
                subjectVertPos = .bottom
            } else {
                subjectVertPos = .middle
            }
        } else {
            subjectVertPos = nil
        }

        // 얼굴 geometry
        let faceYaw = faceResult?.yaw.map { Double(truncating: $0) }
        let facePitch = faceResult?.pitch.map { Double(truncating: $0) }

        let cameraAngle: CameraAngle?
        let gazeDirection: GazeDirection?

        if let pitch = facePitch {
            if pitch > 0.3 {
                cameraAngle = .lowAngle
            } else if pitch < -0.2 {
                cameraAngle = .highAngle
            } else {
                cameraAngle = .eyeLevel
            }
        } else {
            // 얼굴 미검출 — 사람 박스 위치로 앵글 추정
            cameraAngle = estimateCameraAngle(from: subjectBBox)
        }

        if let yaw = faceYaw {
            gazeDirection = abs(yaw) < 0.25 ? .toCamera : .awayFromCamera
        } else {
            gazeDirection = faceResult == nil ? nil : .unknown
        }

        // 단계 E — ShotStyle 라벨링
        let (detectedStyle, styleConfidence) = classifyStyle(
            cameraAngle: cameraAngle,
            gazeDirection: gazeDirection,
            subjectCoverage: subjectCoverage,
            subjectBBox: subjectBBox,
            faceYaw: faceYaw,
            facePitch: facePitch,
            focalLength35mm: exif.focalLength35mm
        )

        return ShotRecipe(
            focalLength35mm: exif.focalLength35mm,
            aperture: exif.aperture,
            iso: exif.iso,
            shutterSpeed: exif.shutterSpeed,
            subjectCoverage: subjectCoverage,
            subjectVerticalPosition: subjectVertPos,
            subjectBoundingBox: subjectBBox,
            cameraAngle: cameraAngle,
            gazeDirection: gazeDirection,
            faceYaw: faceYaw,
            facePitch: facePitch,
            horizonTilt: nil,
            detectedStyle: detectedStyle,
            styleConfidence: styleConfidence
        )
    }

    // MARK: - Step A: EXIF

    private struct EXIFData {
        var focalLength35mm: Double?
        var aperture: Double?
        var iso: Int?
        var shutterSpeed: Double?
    }

    private func extractEXIF(from data: Data) -> EXIFData {
        var result = EXIFData()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return result }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return result }
        guard let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] else { return result }

        if let focal = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double {
            result.focalLength35mm = focal
        } else if let focal = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int {
            result.focalLength35mm = Double(focal)
        }

        if let fnum = exif[kCGImagePropertyExifFNumber] as? Double {
            result.aperture = fnum
        }

        if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = isoArray.first {
            result.iso = first
        } else if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings] as? [Double], let first = isoArray.first {
            result.iso = Int(first)
        }

        if let exposure = exif[kCGImagePropertyExifExposureTime] as? Double {
            result.shutterSpeed = exposure
        }

        return result
    }

    // MARK: - Step B: VNDetectHumanRectanglesRequest

    private struct HumanDetectionResult {
        let boundingBox: CGRect  // Vision bottom-left origin
    }

    private func detectHuman(in pixelBuffer: CVPixelBuffer) -> HumanDetectionResult? {
        var largest: VNHumanObservation?
        let request = VNDetectHumanRectanglesRequest { req, _ in
            let observations = req.results as? [VNHumanObservation] ?? []
            largest = observations.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
        }
        // revision 2 (iOS 15+)
        if #available(iOS 15, *) {
            request.revision = VNDetectHumanRectanglesRequestRevision2
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])

        guard let obs = largest else { return nil }
        return HumanDetectionResult(boundingBox: obs.boundingBox)
    }

    // MARK: - Step C: VNDetectFaceLandmarksRequest

    private func detectFace(in pixelBuffer: CVPixelBuffer) -> VNFaceObservation? {
        var topFace: VNFaceObservation?
        let request = VNDetectFaceLandmarksRequest { req, _ in
            let faces = req.results as? [VNFaceObservation] ?? []
            // 가장 큰 얼굴을 선택
            topFace = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        return topFace
    }

    // MARK: - Camera angle fallback (no face)

    /// 얼굴 미검출 시 사람 박스 위치(top-left origin)로 앵글을 추정한다.
    /// - midY < 0.35  → .highAngle
    /// - midY > 0.65  → .lowAngle
    /// - else          → .eyeLevel (중앙 범위에서 사람이 화면 중앙에 있으면 eye-level 추정이 합리적)
    private func estimateCameraAngle(from bbox: CodableRect?) -> CameraAngle? {
        guard let box = bbox else { return nil }
        let midY = box.y + box.height / 2.0
        if midY < 0.35 { return .highAngle }
        if midY > 0.65 { return .lowAngle }
        return .eyeLevel
    }

    // MARK: - Step E: ShotStyle classification

    private func classifyStyle(
        cameraAngle: CameraAngle?,
        gazeDirection: GazeDirection?,
        subjectCoverage: Double?,
        subjectBBox: CodableRect?,
        faceYaw: Double?,
        facePitch: Double?,
        focalLength35mm: Double?
    ) -> (ShotStyle, ShotStyleConfidence) {

        let coverage = subjectCoverage ?? 0.0
        let gaze = gazeDirection ?? .unknown

        // 1. aerialSelfie — 높은 앵글 + 카메라 응시 + 피사체 25% 이상
        if cameraAngle == .highAngle && gaze == .toCamera && coverage >= 0.25 {
            let confidence: ShotStyleConfidence = (facePitch != nil && faceYaw != nil) ? .high : .medium
            return (.aerialSelfie, confidence)
        }

        // 2. mirrorSelfie — eye-level + 카메라 외면 + 피사체 15% 이상
        // 임계값 35% → 15%: 멀리서 거울로 찍은 와이드 거울샷 포함.
        // gaze=awayFromCamera + eyeLevel 조합 자체가 강한 시그널 → false positive 우려 적음.
        // Confidence: focal ≤ 28 + coverage ≥ 0.35 → high, 그 외 → medium.
        if gaze == .awayFromCamera && cameraAngle == .eyeLevel && coverage >= 0.15 {
            let confidence: ShotStyleConfidence
            if let focal = focalLength35mm, focal <= 28.0, coverage >= 0.35 {
                confidence = .high
            } else {
                confidence = .medium
            }
            return (.mirrorSelfie, confidence)
        }

        // 3. wideSelfie — 카메라 응시 + nil이 아닌 모든 각도 + coverage 10~40% + focal ≤ 50mm 또는 EXIF 없음
        // 임계값 focal 28 → 50: 망원/표준 화각 셀피(35mm·50mm급) 포함.
        // cameraAngle 조건 완화: eyeLevel/highAngle → nil이 아닌 모든 각도 (lowAngle 셀피도 허용).
        // Confidence: focal ≤ 28 → high, focal 29~50 → medium, focal nil → low.
        let isWideSelfieAngle = cameraAngle != nil
        let isWideSeflieFocal = focalLength35mm == nil || focalLength35mm! <= 50.0
        if gaze == .toCamera && isWideSelfieAngle && coverage >= 0.10 && coverage < 0.40 && isWideSeflieFocal {
            let confidence: ShotStyleConfidence
            if let focal = focalLength35mm, focal <= 28.0, facePitch != nil && faceYaw != nil {
                confidence = .high
            } else if focalLength35mm != nil {
                confidence = .medium
            } else {
                confidence = .low
            }
            return (.wideSelfie, confidence)
        }

        // 4. classicSelfie — eye-level + 카메라 응시 + 피사체 40% 이상 (인스타 정면 셀피)
        if gaze == .toCamera && cameraAngle == .eyeLevel && coverage >= 0.40 {
            let confidence: ShotStyleConfidence
            if facePitch != nil && faceYaw != nil {
                confidence = .high
            } else if facePitch != nil || faceYaw != nil {
                confidence = .medium
            } else {
                confidence = .medium
            }
            return (.classicSelfie, confidence)
        }

        // 5. footShot — 낮은 앵글 또는 피사체 하단 위치 + 커버리지 20% 미만 + 시선 외면/불명
        let isLowOrBottom = cameraAngle == .lowAngle || (subjectBBox.map {
            $0.y + $0.height / 2.0 > 0.65
        } ?? false)
        let gazeNotToCamera = gaze == .awayFromCamera || gaze == .unknown
        if isLowOrBottom && coverage < 0.20 && gazeNotToCamera {
            let confidence: ShotStyleConfidence = (subjectBBox != nil && subjectCoverage != nil) ? .high : .low
            return (.footShot, confidence)
        }

        // 6. backView — 얼굴 미검출(yaw == nil) + 피사체 30% 이상
        if faceYaw == nil && coverage >= 0.30 {
            let confidence: ShotStyleConfidence
            if let box = subjectBBox {
                let aspectRatio = box.height / max(box.width, 0.001)
                confidence = aspectRatio > 1.5 ? .high : .medium
            } else {
                confidence = .medium
            }
            return (.backView, confidence)
        }

        // 7. closeUp — 피사체가 65% 이상을 차지하며 위 규칙에 모두 미해당인 경우
        // (대형 오브젝트, 화면 꽉 찬 꽃·음식 등 비인물 접사 포함)
        if coverage >= 0.65 {
            // 얼굴 geometry가 명확하면 medium, 그 외 medium (확실도가 낮아 high로 올리지 않음)
            return (.closeUp, .medium)
        }

        // 8. landscape — 피사체 없거나 coverage 10% 미만 (풍경/배경 중심)
        // 임계값 5% → 10%: 사람이 7~9%로 작은 여행 풍경·배경 사진까지 풍경으로 라벨링.
        if subjectCoverage == nil || coverage < 0.10 {
            let confidence: ShotStyleConfidence = (focalLength35mm != nil) ? .high : .medium
            return (.landscape, confidence)
        }

        // 9. unknown — 위 모두 해당 없음
        return (.unknown, .low)
    }

    // MARK: - Private: Data → CVPixelBuffer

    /// Data를 UIImage를 거쳐 CVPixelBuffer(kCVPixelFormatType_32BGRA)로 변환한다.
    private func makePixelBuffer(from data: Data) -> CVPixelBuffer? {
        guard let cgImage = makeCGImage(from: data) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
