//
//  DIContainer.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import Foundation

@MainActor
final class DIContainer {
    let photoRepository: PhotoRepositoryProtocol
    let savePhotoUseCase: SavePhotoUseCase

    init() {
        self.photoRepository = LocalPhotoRepository()
        self.savePhotoUseCase = SavePhotoUseCase(repository: photoRepository)
    }

    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(savePhotoUseCase: savePhotoUseCase)
    }
}
