//
//  ReferenceAccuracyTests.swift
//  LensNoteTests
//
//  레퍼런스 인식 정확도 평가 하니스. 자세한 워크플로우는 docs/REFERENCE_EVAL.md 참고.
//
//  - generateLabelDrafts: references/의 이미지를 분석해 labels.draft.json + _previews/(박스 그림) 생성.
//  - scoreAccuracy: labels.json(검수본)과 분석기 출력을 비교해 축별 인식 정확도를 콘솔에 출력.
//
//  시뮬레이터 테스트는 호스트 Mac 파일시스템을 직접 읽고 쓴다(이미지 번들링 불필요).
//

import Testing
import Foundation
import UIKit
@testable import LensNote

// MARK: - Label schema (labels.json / labels.draft.json)

private struct EvalLabelFile: Codable {
    var version: Int
    var tolerances: EvalTolerances
    var items: [EvalLabel]
}

private struct EvalTolerances: Codable {
    var coverage: Double
    var iou: Double
}

private struct EvalLabel: Codable {
    var image: String
    var verified: Bool?
    var subjectBox: EvalRect?   // null = 사람 없음
    var cameraAngle: String?    // highAngle | eyeLevel | lowAngle | null
    var category: String?
    var notes: String?
}

private struct EvalRect: Codable {
    var x: Double, y: Double, width: Double, height: Double
    var area: Double { max(0, width) * max(0, height) }
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

// MARK: - Harness

struct ReferenceAccuracyTests {

    // MARK: 경로

    /// 레포 루트의 EvalAssets/ (앱/테스트 번들 밖, 호스트 경로).
    private static var evalDir: URL {
        // 이 소스 파일: <repo>/LensNoteTests/ReferenceAccuracyTests.swift → 두 단계 위가 레포 루트.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // LensNoteTests/
            .deletingLastPathComponent()   // <repo>/
            .appendingPathComponent("EvalAssets")
    }
    private static var referencesDir: URL { evalDir.appendingPathComponent("references") }
    private static var labelsURL: URL { evalDir.appendingPathComponent("labels.json") }
    private static var draftURL: URL { evalDir.appendingPathComponent("labels.draft.json") }
    private static var previewsDir: URL { evalDir.appendingPathComponent("_previews") }
    private static var gtPreviewsDir: URL { evalDir.appendingPathComponent("_previews_gt") }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

    // MARK: - 채점

    /// labels.json(검수본)과 분석기 출력을 비교해 축별 인식 정확도를 출력한다.
    /// labels.json이 없거나 검수된 항목이 없으면 조용히 통과(데이터 투입 전 일반 테스트에 영향 없음).
    @Test("레퍼런스 인식 정확도 채점")
    func scoreAccuracy() async throws {
        guard let data = try? Data(contentsOf: Self.labelsURL),
              let file = try? JSONDecoder().decode(EvalLabelFile.self, from: data) else {
            print("[Eval] labels.json 없음 — 채점 스킵. (docs/REFERENCE_EVAL.md 참고)")
            return
        }
        let verified = file.items.filter { $0.verified == true }
        guard !verified.isEmpty else {
            print("[Eval] 검수된(verified:true) 항목 없음 — 채점 스킵.")
            return
        }

        var presence = 0, coverage = 0, position = 0, angle = 0
        var scored = 0
        var lines: [String] = []

        for label in verified {
            let imgURL = Self.referencesDir.appendingPathComponent(label.image)
            guard let imgData = try? Data(contentsOf: imgURL) else {
                lines.append("  ⚠️ \(label.image): 파일 없음")
                continue
            }
            let recipe = await ShotRecipeAnalyzer().analyze(imageData: imgData)
            scored += 1

            // presence
            let predHasBox = recipe.subjectBoundingBox != nil
            let labelHasBox = label.subjectBox != nil
            let presenceOK = predHasBox == labelHasBox
            if presenceOK { presence += 1 }

            // coverage / position — 양쪽 다 박스 있을 때만 평가
            var coverageOK = false, positionOK = false
            if let pred = recipe.subjectBoundingBox?.cgRect, let lbl = label.subjectBox {
                let predCoverage = recipe.subjectCoverage ?? Double(pred.width * pred.height)
                coverageOK = abs(predCoverage - lbl.area) <= file.tolerances.coverage
                positionOK = Self.iou(pred, lbl.cgRect) >= file.tolerances.iou
            } else if !labelHasBox && !predHasBox {
                // 둘 다 사람 없음 → 박스 축은 해당 없음(정답으로 간주).
                coverageOK = true
                positionOK = true
            }
            if coverageOK { coverage += 1 }
            if positionOK { position += 1 }

            // angle
            let predAngle = recipe.cameraAngle?.rawValue
            let angleOK = predAngle == label.cameraAngle
            if angleOK { angle += 1 }

            lines.append("  \(presenceOK ? "✅" : "❌")P \(coverageOK ? "✅" : "❌")C \(positionOK ? "✅" : "❌")I \(angleOK ? "✅" : "❌")A  \(label.image)  pred(box=\(predHasBox), cov=\(recipe.subjectCoverage.map { String(format: "%.2f", $0) } ?? "nil"), angle=\(predAngle ?? "nil"))")
        }

        func pct(_ n: Int) -> String { scored == 0 ? "-" : String(format: "%.1f%%", Double(n) / Double(scored) * 100) }
        let overall = presence + coverage + position + angle
        let report = """

        ===== Reference Perception Accuracy (n=\(scored) verified) =====
        presence   \(presence)/\(scored)  (\(pct(presence)))
        coverage   \(coverage)/\(scored)  (\(pct(coverage)))
        position   \(position)/\(scored)  (\(pct(position)))   ← IoU
        angle      \(angle)/\(scored)  (\(pct(angle)))
        ---------------------------------------------------------------
        overall    \(overall)/\(scored * 4)  (\(scored == 0 ? "-" : String(format: "%.1f%%", Double(overall) / Double(scored * 4) * 100)))

        \(lines.joined(separator: "\n"))
        """
        print(report)
    }

    // MARK: - 초안 + 미리보기 생성

    /// references/의 모든 이미지를 분석해 labels.draft.json과 박스 미리보기를 생성한다.
    /// (검수의 출발점. 사용자는 _previews/를 보고 draft를 labels.json으로 교정.)
    /// 멱등: labels.draft.json이 이미 있으면 건너뛴다 → 전체 테스트에서 매번 재생성/지연되지 않음.
    /// 재생성하려면 labels.draft.json을 삭제 후 실행.
    @Test("라벨 초안 + 미리보기 생성")
    func generateLabelDrafts() async throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: Self.draftURL.path) else {
            print("[Eval] labels.draft.json 이미 존재 — 재생성하려면 파일 삭제 후 실행.")
            return
        }
        guard let files = try? fm.contentsOfDirectory(at: Self.referencesDir, includingPropertiesForKeys: nil) else {
            print("[Eval] references/ 없음 — 이미지를 먼저 넣으세요.")
            return
        }
        let images = files
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !images.isEmpty else {
            print("[Eval] references/에 이미지 없음.")
            return
        }
        try? fm.createDirectory(at: Self.previewsDir, withIntermediateDirectories: true)

        var items: [EvalLabel] = []
        for url in images {
            guard let data = try? Data(contentsOf: url) else { continue }
            let recipe = await ShotRecipeAnalyzer().analyze(imageData: data)
            let box = recipe.subjectBoundingBox.map {
                EvalRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
            }
            items.append(EvalLabel(
                image: url.lastPathComponent,
                verified: false,
                subjectBox: box,
                cameraAngle: recipe.cameraAngle?.rawValue,
                category: Self.roughCategory(coverage: recipe.subjectCoverage),
                notes: "draft: style=\(recipe.detectedStyle.rawValue), conf=\(recipe.styleConfidence.rawValue)"
            ))
            // 박스 미리보기 저장
            if let img = UIImage(data: data) {
                let preview = Self.drawBox(box?.cgRect, on: img)
                if let out = preview.jpegData(compressionQuality: 0.9) {
                    try? out.write(to: Self.previewsDir.appendingPathComponent(url.lastPathComponent))
                }
            }
        }

        let draft = EvalLabelFile(
            version: 1,
            tolerances: EvalTolerances(coverage: 0.10, iou: 0.5),
            items: items
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let out = try enc.encode(draft)
        try out.write(to: Self.draftURL)
        print("[Eval] labels.draft.json 생성(\(items.count)건) + _previews/ 박스 미리보기 저장 완료.")
        print("[Eval] 다음: _previews/ 확인 → draft를 labels.json으로 복사 후 틀린 것만 교정 + verified:true.")
    }

    // MARK: - GT 라벨 미리보기 (검수용)

    /// labels.json의 subjectBox를 이미지 위에 파란 박스로 그려 _previews_gt/에 저장한다.
    /// (분석기 박스가 아니라 손검수 ground-truth를 눈으로 확인하기 위함.)
    /// 매번 재생성(멱등 아님) — 라벨 교정 후 다시 그려 확인.
    @Test("GT 라벨 박스 미리보기 생성")
    func renderLabelPreviews() async throws {
        guard let data = try? Data(contentsOf: Self.labelsURL),
              let file = try? JSONDecoder().decode(EvalLabelFile.self, from: data) else {
            print("[Eval] labels.json 없음 — GT 미리보기 스킵.")
            return
        }
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.gtPreviewsDir, withIntermediateDirectories: true)
        var count = 0
        for label in file.items {
            let imgURL = Self.referencesDir.appendingPathComponent(label.image)
            guard let imgData = try? Data(contentsOf: imgURL), let img = UIImage(data: imgData) else { continue }
            let preview = Self.drawBox(label.subjectBox?.cgRect, on: img, color: .systemBlue)
            if let out = preview.jpegData(compressionQuality: 0.9) {
                try? out.write(to: Self.gtPreviewsDir.appendingPathComponent(label.image))
                count += 1
            }
        }
        print("[Eval] _previews_gt/ GT 박스 미리보기 \(count)건 저장 완료.")
    }

    // MARK: - Helpers

    /// 두 정규화 사각형의 IoU.
    private static func iou(_ a: CGRect, _ b: CGRect) -> Double {
        let inter = a.intersection(b)
        let interArea = inter.isNull ? 0 : Double(inter.width * inter.height)
        let union = Double(a.width * a.height) + Double(b.width * b.height) - interArea
        return union <= 0 ? 0 : interArea / union
    }

    /// coverage 기반 거친 카테고리 추정(정보용 초안).
    private static func roughCategory(coverage: Double?) -> String {
        guard let c = coverage else { return "landscape" }
        if c >= 0.6 { return "closeUp" }
        if c >= 0.3 { return "halfBody" }
        if c >= 0.05 { return "fullBody" }
        return "landscape"
    }

    /// 정규화 박스를 이미지 위에 그려 미리보기 이미지를 만든다.
    private static func drawBox(_ box: CGRect?, on image: UIImage, color: UIColor = .systemGreen) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            image.draw(at: .zero)
            guard let box else { return }
            let rect = CGRect(
                x: box.origin.x * image.size.width,
                y: box.origin.y * image.size.height,
                width: box.size.width * image.size.width,
                height: box.size.height * image.size.height
            )
            ctx.cgContext.setStrokeColor(color.cgColor)
            ctx.cgContext.setLineWidth(max(image.size.width, image.size.height) * 0.006)
            ctx.cgContext.stroke(rect)
        }
    }
}
