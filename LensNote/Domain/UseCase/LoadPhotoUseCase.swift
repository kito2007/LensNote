//
//  LoadPhotoUseCase.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import Foundation

struct LoadPhotosUseCase {
    let repository: PhotoRepositoryProtocol

    func execute() throws -> [PhotoItem] {
        try repository.fetchAll()
    }
}
