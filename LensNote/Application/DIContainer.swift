//
//  DIContainer.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import Foundation

/// 의존성 생성/조합을 담당하는 간단한 DI 컨테이너.
/// 현재 앱 엔트리에서는 직접 생성 방식을 쓰지만, 테스트/모듈화 시 이 타입을 재활용할 수 있다.
@MainActor
final class DIContainer {
    let photoRepository: PhotoRepositoryProtocol
    let savePhotoUseCase: SavePhotoUseCase

    init() {
        self.photoRepository = FilePhotoRepository()
        self.savePhotoUseCase = SavePhotoUseCase(repository: photoRepository)
    }

    /// Camera 탭에서 사용할 ViewModel 팩토리.
    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(savePhotoUseCase: savePhotoUseCase)
    }

    /// Map 탭에서 사용할 ViewModel 팩토리.
    /// FetchPhotoPinsUseCase를 주입하여 LensNote 저장 사진을 지도에 표시할 수 있게 한다.
    func makeMapViewModel() -> MapViewModel {
        let fetchUseCase = FetchPhotoPinsUseCase(repository: photoRepository)
        return MapViewModel(fetchPhotoPinsUseCase: fetchUseCase)
    }

    /// Profile 탭 ViewModel 팩토리 — 저장된 PhotoItem으로 촬영 통계를 계산한다(Req 5).
    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(fetchUseCase: FetchPhotoPinsUseCase(repository: photoRepository))
    }
}
