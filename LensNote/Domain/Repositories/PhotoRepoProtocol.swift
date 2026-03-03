//
//  PhotoRepo.swift
//  LensNote
//
//  Created by 박태영 on 12/24/25.
//

import Foundation

/// 사진 메타데이터 저장소 추상화.
/// 메모리/파일/DB 구현을 교체하더라도 상위 계층 코드를 유지하기 위한 인터페이스.
protocol PhotoRepositoryProtocol {
    /// 단일 사진 메타데이터 저장.
    func save(_ item: PhotoItem) throws
    /// 저장된 전체 사진 메타데이터 조회.
    func fetchAll() throws -> [PhotoItem]
}
