//
//  SavePhotoUseCase.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import Foundation

struct SavePhotoUseCase {
    let repository: PhotoRepositoryProtocol

    func execute(imagePath: String, coordinate: GeoCoordinate?) throws -> PhotoItem {
        let item = PhotoItem(
            id: UUID(),
            createdAt: Date(),
            imagePath: imagePath,
            coordinate: coordinate
        )
        try repository.save(item)
        return item
    }
}
