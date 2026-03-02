//
//  GuidanceDatasetRecorder.swift
//  LensNote
//
//  Created by Codex on 2/25/26.
//

import Foundation
import OSLog

struct GuidanceDatasetRecord: Codable {
    let timestamp: String
    let concept: String
    let guidanceMessage: String
    let confidence: Double
    let source: String
    let acceptedForUI: Bool
    let features: CompositionFeatureSnapshot
}

final class GuidanceDatasetRecorder {
    private let queue = DispatchQueue(label: "GuidanceDatasetRecorderQueue")
    private let logger = Logger(subsystem: "LensNote", category: "GuidanceDataset")
    private let encoder = JSONEncoder()

    private var fileURL: URL?
    private var didLogPath = false
    private var lastRecordTime = Date.distantPast
    private let minimumRecordInterval: TimeInterval = 0.4
    private let timestampFormatter = ISO8601DateFormatter()

    init() {
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    func record(result: CompositionGuidanceResult, concept: String, acceptedForUI: Bool) {
        let now = Date()
        guard now.timeIntervalSince(lastRecordTime) >= minimumRecordInterval else { return }
        lastRecordTime = now

        let record = GuidanceDatasetRecord(
            timestamp: timestampFormatter.string(from: now),
            concept: concept,
            guidanceMessage: result.message,
            confidence: result.confidence,
            source: result.source.rawValue,
            acceptedForUI: acceptedForUI,
            features: result.featureSnapshot
        )

        queue.async { [weak self] in
            self?.append(record)
        }
    }

    private func append(_ record: GuidanceDatasetRecord) {
        do {
            let url = try resolveFileURL()
            let data = try encoder.encode(record)
            var lineData = data
            lineData.append(0x0A) // newline

            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: lineData)
        } catch {
            logger.error("Failed to append guidance dataset record: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resolveFileURL() throws -> URL {
        if let fileURL { return fileURL }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let baseURL = documents ?? FileManager.default.temporaryDirectory
        let directory = baseURL.appendingPathComponent("LensNoteAnalytics", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let resolved = directory.appendingPathComponent("composition_guidance_samples.jsonl")
        fileURL = resolved
        if !didLogPath {
            logger.info("Guidance dataset is being recorded at: \(resolved.path, privacy: .public)")
            didLogPath = true
        }
        return resolved
    }
}
