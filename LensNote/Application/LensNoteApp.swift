//
//  LensNoteApp.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI

/// 앱 진입점.
/// 공용 repository 인스턴스를 한 번만 만들고 각 탭 ViewModel에 주입한다.
@main
struct LensNoteApp: App {

    // ✅ 하나의 Repository 인스턴스를 공유해야
    // Camera에서 저장한 데이터가 지도 갤러리에도 반영됨
    private let photoRepository = LocalPhotoRepository()

    var body: some Scene {
        WindowGroup {
            // 저장 유스케이스를 Camera ViewModel에 주입
            let saveUseCase = SavePhotoUseCase(repository: photoRepository)

            let cameraVM = CameraViewModel(savePhotoUseCase: saveUseCase)

            RootView(cameraVM: cameraVM)
        }
    }
}
