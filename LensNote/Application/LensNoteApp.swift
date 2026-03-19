//
//  LensNoteApp.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI

/// 앱 진입점.
/// DIContainer를 이용해 카메라 기능 관련 의존성을 추가한다.
@main
struct LensNoteApp: App {
    
    private let container: DIContainer
    private let cameraVM: CameraViewModel
    
    init(){
        self.container = DIContainer()
        self.cameraVM = container.makeCameraViewModel()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(cameraVM: cameraVM)
        }
    }
}
