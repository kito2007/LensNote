//
//  CameraViewModel.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import Combine
import Foundation

@MainActor
final class CameraView: ObservableObject {
    var objectWillChange: ObservableObjectPublisher
    
    @Published var statusText: String = "카메라 준비 중..."

    private let savePhotoUseCase: SavePhotoUseCase

    init(savePhotoUseCase: SavePhotoUseCase) {
        self.savePhotoUseCase = savePhotoUseCase
    }

    func onAppear() {
        statusText = "스타일 적용됨"
    }
}
