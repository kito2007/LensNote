//
//  CameraViewModel.swift
//  LensNote
//
//  Created by 박태영 on 1/1/26.
//

// LensNote/Features/Camera/CameraViewModel.swift

import Foundation
import Combine

@MainActor
final class CameraViewModel: ObservableObject {
    // var objectWillChange: ObservableObjectPublisher

    private let savePhotoUseCase: SavePhotoUseCase

    @Published var lastSaved: PhotoItem? = nil
    @Published var errorMessage: String? = nil

    init(savePhotoUseCase: SavePhotoUseCase) {
        self.savePhotoUseCase = savePhotoUseCase
    }

    func mockCaptureAndSave() {
        do {
            let item = try savePhotoUseCase.execute(
                imagePath: "mock/path.jpg",
                coordinate: nil
            )
            lastSaved = item
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

