//
//  LocalPhotoRepository.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

// LensNote/Domain/Repositories/LocalPhotoRepository.swift

import Foundation

/// 앱 실행 중 메모리에만 유지되는 로컬 저장소 구현.
/// 프로토타입 단계에서 저장 경로/DB 없이 동작 확인용으로 사용한다.
final class LocalPhotoRepository: PhotoRepositoryProtocol {

    private var items: [PhotoItem] = []

    /// 저장은 단순 append 방식.
    func save(_ item: PhotoItem) throws {
        items.append(item)
    }

    /// 현재 메모리에 있는 전체 목록 반환.
    func fetchAll() throws -> [PhotoItem] {
        items
    }
}
