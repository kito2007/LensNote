//
//  FilePhotoRepository.swift
//  LensNote
//

import Foundation

/// 앱 Document 디렉토리에 JSON 파일로 PhotoItem 목록을 유지하는 저장소 구현.
/// 앱을 재시작해도 LensNote 촬영 사진 핀이 유지된다.
final class FilePhotoRepository: PhotoRepositoryProtocol {

    // MARK: - Private

    private let fileURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photo_items.json")
    }()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - PhotoRepositoryProtocol

    /// 기존 배열을 디스크에서 읽어 새 항목을 추가한 뒤 다시 기록한다.
    func save(_ item: PhotoItem) throws {
        var existing = try fetchAll()
        existing.append(item)
        let data = try encoder.encode(existing)
        try data.write(to: fileURL, options: .atomic)
    }

    /// 디스크에서 JSON을 읽어 반환한다. 파일이 없으면 빈 배열을 돌려준다.
    func fetchAll() throws -> [PhotoItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([PhotoItem].self, from: data)
    }
}
