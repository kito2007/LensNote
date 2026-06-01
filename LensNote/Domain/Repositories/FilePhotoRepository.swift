//
//  FilePhotoRepository.swift
//  LensNote
//

import Foundation
import os

/// 영속화 JSON 최상위 구조. schemaVersion으로 스키마 진화를 추적한다.
struct PhotoStorageEnvelope: Codable {
    let schemaVersion: Int
    let items: [PhotoItem]

    /// 현재 앱이 기록하는 스키마 버전.
    static let currentVersion = 1
}

/// 앱 Document 디렉토리에 JSON 파일로 PhotoItem 목록을 유지하는 저장소 구현.
/// 앱을 재시작해도 LensNote 촬영 사진 핀이 유지된다.
/// 최상위에 schemaVersion을 둔 PhotoStorageEnvelope로 저장하며,
/// 구버전(envelope 이전의 bare array) 데이터는 읽는 시점에 마이그레이션한다.
final class FilePhotoRepository: PhotoRepositoryProtocol {

    // MARK: - Private

    private let fileURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photo_items.json")
    }()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let log = Logger(subsystem: "com.PTY.LensNote", category: "FilePhotoRepository")

    // MARK: - PhotoRepositoryProtocol

    /// 기존 배열을 디스크에서 읽어 새 항목을 추가한 뒤 envelope로 다시 기록한다.
    func save(_ item: PhotoItem) throws {
        var existing = fetchAll()
        existing.append(item)
        let envelope = PhotoStorageEnvelope(
            schemaVersion: PhotoStorageEnvelope.currentVersion,
            items: existing
        )
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }

    /// 디스크에서 JSON을 읽어 반환한다.
    /// - 파일이 없으면 빈 배열.
    /// - envelope 디코딩 → 버전 검사 후 마이그레이션.
    /// - envelope 실패 시 구버전 bare array(`[PhotoItem]`)로 재시도(= schemaVersion 0).
    /// - 모두 실패하면 빈 배열 + 에러 로그.
    func fetchAll() -> [PhotoItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            log.error("photo_items.json 읽기 실패: \(error.localizedDescription, privacy: .public)")
            return []
        }

        // 1) 현재 포맷(envelope) 시도
        if let envelope = try? decoder.decode(PhotoStorageEnvelope.self, from: data) {
            return migrate(envelope)
        }

        // 2) 구버전 bare array(schemaVersion 0) 시도 → 마이그레이션
        if let legacyItems = try? decoder.decode([PhotoItem].self, from: data) {
            log.notice("구버전(bare array) 데이터 감지 — schemaVersion 1로 마이그레이션")
            return migrate(PhotoStorageEnvelope(schemaVersion: 0, items: legacyItems))
        }

        // 3) 어떤 포맷으로도 디코딩 불가
        log.error("photo_items.json 디코딩 실패 — 빈 배열 반환")
        return []
    }

    // MARK: - Migration

    /// envelope의 schemaVersion을 현재 버전으로 끌어올린다.
    /// - version == current: 그대로 반환.
    /// - version < current: 단계적 마이그레이션(현재는 0→1 필드 추가뿐이라 변환 불필요).
    /// - version > current: 미지원 — 빈 배열 + 에러 로그.
    private func migrate(_ envelope: PhotoStorageEnvelope) -> [PhotoItem] {
        let current = PhotoStorageEnvelope.currentVersion

        if envelope.schemaVersion > current {
            log.error("지원하지 않는 미래 schemaVersion(\(envelope.schemaVersion)) — 빈 배열 반환")
            return []
        }

        // version 0 → 1: PhotoItem에 shotStyle/filterPresetName(optional) 추가.
        // optional 필드라 디코딩 시 자동으로 nil 채워지므로 데이터 변환은 필요 없다.
        // 마이그레이션 체인이 늘어나면 여기에 단계별 변환을 추가한다.
        return envelope.items
    }
}
