//
//  FetchPhotoPinsUseCase.swift
//  LensNote
//
//  Created by 박태영 on 3/31/26.
//

import Foundation

/// LensNote 저장소에서 PhotoItem 목록을 가져오는 유스케이스.
/// MapViewModel에서 LensNote 고유 핀을 로드할 때 사용한다.
struct FetchPhotoPinsUseCase {
    let repository: PhotoRepositoryProtocol

    /// 저장된 전체 PhotoItem 목록을 반환한다.
    func execute() throws -> [PhotoItem] {
        try repository.fetchAll()
    }
}
