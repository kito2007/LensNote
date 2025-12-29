//
//  LensNoteApp.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI

@main
struct LensNoteApp: App {

    let photoRepository = LocalPhotoRepository()

    var body: some Scene {
        WindowGroup {

            let savePhotoUseCase = SavePhotoUseCase(
                repository: photoRepository
            )

            CameraView(
                savePhotoUseCase: CameraViewModel(
                    savePhotoUseCase: savePhotoUseCase
                )
            )
        }
    }
}
