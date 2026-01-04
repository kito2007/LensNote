//
//  LocalPhotoRepository.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

// LensNote/Domain/Repositories/LocalPhotoRepository.swift

import Foundation

final class LocalPhotoRepository: PhotoRepositoryProtocol {

    private var items: [PhotoItem] = []

    func save(_ item: PhotoItem) throws {
        items.append(item)
    }

    func fetchAll() throws -> [PhotoItem] {
        items
    }
}
