//
//  FilePhotoRepositoryTests.swift
//  LensNoteTests
//
//  Req 9.4 / 9.5 — FilePhotoRepository 저장/읽기 라운드트립 + 빈 초기 상태.
//

import Testing
import Foundation
@testable import LensNote

struct FilePhotoRepositoryTests {

    /// 격리된 임시 파일 경로를 가진 저장소를 만든다.
    private func makeTempRepository() -> (FilePhotoRepository, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lensnote_test_\(UUID().uuidString).json")
        return (FilePhotoRepository(fileURL: url), url)
    }

    /// (a) 유효한 PhotoItem을 save한 후 fetchAll 호출 시 동일 객체 포함.
    ///     모든 프로퍼티(id/createdAt/imagePath/coordinate/shotStyle/filterPresetName) 보존(Req 9.5).
    @Test("save → fetchAll 라운드트립")
    func saveThenFetchRoundTrip() throws {
        let (repo, url) = makeTempRepository()
        defer { try? FileManager.default.removeItem(at: url) }

        let item = PhotoItem(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            imagePath: "photos/test.jpg",
            coordinate: GeoCoordinate(latitude: 37.5665, longitude: 126.9780),
            shotStyle: .classicSelfie,
            filterPresetName: "Portrait"
        )

        try repo.save(item)
        let fetched = repo.fetchAll()

        #expect(fetched.count == 1)
        #expect(fetched.first == item)
    }

    /// (b) 파일이 존재하지 않는 초기 상태에서 fetchAll → 빈 배열.
    @Test("파일 없음 → 빈 배열")
    func emptyStateReturnsEmpty() {
        let (repo, url) = makeTempRepository()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(repo.fetchAll().isEmpty)
    }

    /// 구버전 bare array(JSON) → 마이그레이션되어 정상 로드됨 (Req 8.5).
    @Test("구버전 bare array 마이그레이션")
    func legacyArrayMigratesToEnvelope() throws {
        let (repo, url) = makeTempRepository()
        defer { try? FileManager.default.removeItem(at: url) }

        let legacy = PhotoItem(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_600_000_000),
            imagePath: "legacy.jpg",
            coordinate: nil
        )
        // envelope 이전 포맷 = 최상위 배열
        let data = try JSONEncoder().encode([legacy])
        try data.write(to: url, options: .atomic)

        let fetched = repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == legacy.id)
        #expect(fetched.first?.shotStyle == nil)
    }
}
