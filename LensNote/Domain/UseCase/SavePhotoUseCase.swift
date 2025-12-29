//
//  SavePhotoUseCase.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import Foundation

final class SavePhotoUseCase {

    private let repository: PhotoRepositoryProtocol

    init(repository: PhotoRepositoryProtocol) {
        self.repository = repository
    }

    func execute(photo: PhotoItem) throws {
        try repository.save(photo: photo)
    }
}
