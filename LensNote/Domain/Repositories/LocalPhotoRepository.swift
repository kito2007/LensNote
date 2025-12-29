//
//  LocalPhotoRepository.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import Foundation

final class LocalPhotoRepository: PhotoRepositoryProtocol {

    private var storage: [PhotoItem] = []

    func save(photo: PhotoItem) throws {
        storage.append(photo)
    }

    func fetchAll() throws -> [PhotoItem] {
        storage
    }
}
