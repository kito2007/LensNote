//
//  LensNoteApp.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI

@main
struct LensNoteApp: App {

    // ✅ 하나의 Repository 인스턴스를 공유해야
    // Camera에서 저장한 데이터가 지도 갤러리에도 반영됨
    private let photoRepository = LocalPhotoRepository()

    var body: some Scene {
        WindowGroup {
            let saveUseCase = SavePhotoUseCase(repository: photoRepository)

            let cameraVM = CameraViewModel(savePhotoUseCase: saveUseCase)

            RootView(cameraVM: cameraVM)
        }
    }
}
