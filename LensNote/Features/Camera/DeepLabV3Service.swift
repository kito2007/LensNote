//
//  DeepLabV3Service.swift
//  LensNote
//
//  Created by LensNote Engineer on 2026-04-06.
//

import Foundation
import CoreML
import CoreImage
import CoreVideo
import Accelerate
import os

/// DeepLabV3 시맨틱 세그멘테이션 결과.
struct SegmentationResult {
    /// 가장 넓은 면적을 차지하는 비-배경 클래스 인덱스 (배경만 있으면 0).
    let dominantClass: Int
    /// 사람이 읽을 수 있는 클래스 이름.
    let dominantClassName: String
    /// 피사체 바운딩 박스 (정규화 좌표 0~1). 배경만 있으면 nil.
    let subjectBoundingBox: CGRect?
    /// 피사체가 전체 화면에서 차지하는 면적 비율 (0~1).
    let subjectCoverage: Double
    /// 피사체 중심의 삼등분선 교차점 대비 편차 (정규화 -0.5~0.5).
    let ruleOfThirdsOffset: CGPoint
    /// person(클래스 15) 마스크 바운딩 박스 (정규화 0~1). 사람 픽셀이 없으면 nil.
    /// dominantClass가 person이 아니어도(배경 오브젝트가 더 클 때도) 채워진다.
    let personBoundingBox: CGRect?
    /// person(클래스 15)이 화면에서 차지하는 면적 비율 (0~1). 사람 없으면 0.
    let personCoverage: Double
}

/// DeepLabV3 21개 클래스 레이블.
private enum DeepLabClass: Int, CaseIterable {
    case background = 0, aeroplane, bicycle, bird, boat, bottle, bus, car, cat,
         chair, cow, diningTable, dog, horse, motorbike, person,
         pottedPlant, sheep, sofa, train, tvOrMonitor

    var displayName: String {
        switch self {
        case .background: return "background"
        case .aeroplane: return "aeroplane"
        case .bicycle: return "bicycle"
        case .bird: return "bird"
        case .boat: return "boat"
        case .bottle: return "bottle"
        case .bus: return "bus"
        case .car: return "car"
        case .cat: return "cat"
        case .chair: return "chair"
        case .cow: return "cow"
        case .diningTable: return "dining table"
        case .dog: return "dog"
        case .horse: return "horse"
        case .motorbike: return "motorbike"
        case .person: return "person"
        case .pottedPlant: return "potted plant"
        case .sheep: return "sheep"
        case .sofa: return "sofa"
        case .train: return "train"
        case .tvOrMonitor: return "tv/monitor"
        }
    }
}

/// DeepLabV3 CoreML 모델을 래핑하여 시맨틱 세그멘테이션을 수행하는 서비스.
/// nonisolated — 세션 큐(sampleBufferQueue)에서 직접 호출한다.
final class DeepLabV3Service {

    private static let modelInputSize = CGSize(width: 513, height: 513)
    private static let gridSize = 513
    /// 성능을 위해 전체 픽셀 대신 stepSize 간격으로 샘플링한다.
    private static let sampleStride = 8
    /// person 바운딩 박스를 잡을 때 열/행별 person 픽셀 수가 피크의 이 비율 미만이면
    /// 희소한 아웃라이어(세그멘테이션 노이즈)로 보고 박스 경계에서 제외한다.
    /// raw min/max는 스트레이 픽셀 하나가 박스를 프레임 전체로 부풀리므로 밀도 기반으로 강건화.
    /// 값(0.15)은 레퍼런스 평가 하니스로 튜닝 — position(IoU) 82.6→95.7%. 더 높이면(0.20+)
    /// 실제 사지/머리까지 잘라 spread 포즈가 undershoot로 반전되므로 0.15가 스위트스팟.
    private static let boxTrimFraction = 0.15
    private static let logger = Logger(subsystem: "com.PTY.LensNote", category: "DeepLabV3")

    // MARK: - Lazy model load

    private lazy var model: MLModel? = {
        guard let url = Bundle.main.url(forResource: "DeepLabV3", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "DeepLabV3", withExtension: "mlmodel") else {
            return nil
        }
        return try? MLModel(contentsOf: url)
    }()

    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Public API

    /// 픽셀 버퍼를 세그멘테이션한다. 모델 로드 실패 시 nil을 반환한다.
    func segment(pixelBuffer: CVPixelBuffer) -> SegmentationResult? {
        guard let mlModel = model else { return nil }

        // 1. 입력 버퍼를 513x513으로 리사이즈
        guard let resized = resize(pixelBuffer: pixelBuffer, to: Self.modelInputSize) else { return nil }

        // 2. MLFeatureProvider 입력 구성
        guard let inputFeature = try? MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: resized)]) else { return nil }

        // 3. 추론
        guard let output = try? mlModel.prediction(from: inputFeature) else { return nil }

        // 4. semanticPredictions MLMultiArray 추출
        guard let multiArray = output.featureValue(for: "semanticPredictions")?.multiArrayValue else { return nil }

        // 4-1. shape 검증 (Req 10.3) — [513, 513]이 아니면 에러 로그 + nil. 후처리가 잘못된 인덱싱을
        //      하지 않도록 방어한다. (인덱스 오버플로 가드는 별도지만, shape 불일치 자체를 조기 차단.)
        let dims = multiArray.shape.suffix(2).map(\.intValue)
        guard dims == [Self.gridSize, Self.gridSize] else {
            Self.logger.error("DeepLabV3 semanticPredictions shape mismatch: \(multiArray.shape) (expected [..,513,513])")
            return nil
        }

        // 5. stride 샘플링으로 후처리
        return postprocess(multiArray: multiArray)
    }

    // MARK: - Private: resize

    private func resize(pixelBuffer: CVPixelBuffer, to size: CGSize) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = size.width / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let scaleY = size.height / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var output: CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            Int(size.width), Int(size.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &output
        )
        guard let out = output else { return nil }
        ciContext.render(scaled, to: out)
        return out
    }

    // MARK: - Private: postprocess

    private func postprocess(multiArray: MLMultiArray) -> SegmentationResult {
        let gridSize = Self.gridSize
        let stepSize = Self.sampleStride
        let totalClasses = DeepLabClass.allCases.count // 21

        // 클래스별 픽셀 카운트 및 바운딩 박스 추적
        var classCounts = [Int: Int]()
        var classMinX = [Int: Int]()
        var classMaxX = [Int: Int]()
        var classMinY = [Int: Int]()
        var classMaxY = [Int: Int]()

        // person(15) 전용 열/행 히스토그램 — 밀도 기반 강건 박스 계산용.
        let personClass = DeepLabClass.person.rawValue // 15
        var personColCounts = [Int: Int]()
        var personRowCounts = [Int: Int]()

        let totalSampled = (gridSize / stepSize) * (gridSize / stepSize)

        for row in stride(from: 0, to: gridSize, by: stepSize) {
            for col in stride(from: 0, to: gridSize, by: stepSize) {
                let idx = row * gridSize + col
                guard idx < multiArray.count else { continue }
                let classIdx = multiArray[idx].intValue
                guard classIdx >= 0 && classIdx < totalClasses else { continue }

                classCounts[classIdx, default: 0] += 1

                if classMinX[classIdx] == nil || col < classMinX[classIdx]! { classMinX[classIdx] = col }
                if classMaxX[classIdx] == nil || col > classMaxX[classIdx]! { classMaxX[classIdx] = col }
                if classMinY[classIdx] == nil || row < classMinY[classIdx]! { classMinY[classIdx] = row }
                if classMaxY[classIdx] == nil || row > classMaxY[classIdx]! { classMaxY[classIdx] = row }

                if classIdx == personClass {
                    personColCounts[col, default: 0] += 1
                    personRowCounts[row, default: 0] += 1
                }
            }
        }

        // person(15) 클래스를 별도로 추출한다 — dominant 클래스가 아니어도(배경 오브젝트가
        // 더 클 때도) 인물 중심 앱이 사람 마스크를 쓸 수 있도록. (평가셋 003/009처럼 식탁·차가
        // 사람보다 넓어 dominant가 person이 아닌 경우 미검출되던 문제 해결.)
        let personBox: CGRect?
        let personCoverage: Double
        if let pCount = classCounts[personClass], pCount > 0,
           let colB = Self.robustBounds(counts: personColCounts, trimFraction: Self.boxTrimFraction),
           let rowB = Self.robustBounds(counts: personRowCounts, trimFraction: Self.boxTrimFraction) {
            // raw min/max 대신 밀도 기반 강건 경계 — 스트레이 노이즈 픽셀로 박스가 부풀지 않게.
            let nx = Double(colB.min) / Double(gridSize)
            let xx = Double(colB.max) / Double(gridSize)
            let ny = Double(rowB.min) / Double(gridSize)
            let xy = Double(rowB.max) / Double(gridSize)
            personBox = CGRect(x: nx, y: ny, width: xx - nx, height: xy - ny)
            // coverage(마스크 픽셀비율)는 정확하므로 트리밍과 무관하게 전체 person 픽셀로 계산.
            personCoverage = Double(pCount) / Double(max(totalSampled, 1))
        } else {
            personBox = nil
            personCoverage = 0
        }

        // 배경(0) 제외 가장 넓은 클래스 찾기
        let nonBackgroundCounts = classCounts.filter { $0.key != 0 }
        guard let dominantEntry = nonBackgroundCounts.max(by: { $0.value < $1.value }) else {
            // 피사체가 없는 경우 — 배경만
            return SegmentationResult(
                dominantClass: 0,
                dominantClassName: DeepLabClass.background.displayName,
                subjectBoundingBox: nil,
                subjectCoverage: 0,
                ruleOfThirdsOffset: .zero,
                personBoundingBox: personBox,
                personCoverage: personCoverage
            )
        }

        let domClass = dominantEntry.key
        let domCount = dominantEntry.value
        let coverage = Double(domCount) / Double(max(totalSampled, 1))

        // 정규화 바운딩 박스
        let minX = Double(classMinX[domClass]!) / Double(gridSize)
        let maxX = Double(classMaxX[domClass]!) / Double(gridSize)
        let minY = Double(classMinY[domClass]!) / Double(gridSize)
        let maxY = Double(classMaxY[domClass]!) / Double(gridSize)
        let bbox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // 피사체 중심
        let centerX = (minX + maxX) / 2.0
        let centerY = (minY + maxY) / 2.0

        // 삼등분선 교차점 4개: (1/3,1/3),(2/3,1/3),(1/3,2/3),(2/3,2/3)
        let thirds: [(Double, Double)] = [(1/3, 1/3), (2/3, 1/3), (1/3, 2/3), (2/3, 2/3)]
        let nearest = thirds.min(by: {
            let dx0 = $0.0 - centerX; let dy0 = $0.1 - centerY
            let dx1 = $1.0 - centerX; let dy1 = $1.1 - centerY
            return dx0*dx0 + dy0*dy0 < dx1*dx1 + dy1*dy1
        })!
        let offsetX = centerX - nearest.0
        let offsetY = centerY - nearest.1

        let className = DeepLabClass(rawValue: domClass)?.displayName ?? "unknown"

        return SegmentationResult(
            dominantClass: domClass,
            dominantClassName: className,
            subjectBoundingBox: bbox,
            subjectCoverage: coverage,
            ruleOfThirdsOffset: CGPoint(x: offsetX, y: offsetY),
            personBoundingBox: personBox,
            personCoverage: personCoverage
        )
    }

    /// 밀도 기반 강건 경계. 열(또는 행)별 person 픽셀 카운트 히스토그램에서
    /// 피크 대비 `trimFraction` 미만인 희소 열/행을 아웃라이어로 보고 제외한 뒤
    /// 남은 열/행의 최소·최대 좌표를 반환한다. 스트레이 픽셀 하나가 박스를
    /// 프레임 전체로 부풀리는 것을 막는다. (peak가 0이거나 비면 nil.)
    private static func robustBounds(counts: [Int: Int], trimFraction: Double) -> (min: Int, max: Int)? {
        guard let peak = counts.values.max(), peak > 0 else { return nil }
        let threshold = max(1, Int((Double(peak) * trimFraction).rounded()))
        let kept = counts.filter { $0.value >= threshold }.keys
        guard let lo = kept.min(), let hi = kept.max() else { return nil }
        return (lo, hi)
    }
}
