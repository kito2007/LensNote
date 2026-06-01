//
//  SavePhotoUseCase.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import Foundation

/// 촬영 결과를 저장소에 기록하는 유스케이스.
/// ViewModel은 저장 상세 구현을 몰라도 되도록 이 레이어를 통해 호출한다.
struct SavePhotoUseCase {
    let repository: PhotoRepositoryProtocol

    /// 경로/좌표/촬영 메타데이터를 받아 PhotoItem을 생성하고 저장 후 반환한다.
    func execute(
        imagePath: String,
        coordinate: GeoCoordinate?,
        shotStyle: ShotStyle? = nil,
        filterPresetName: String? = nil
    ) throws -> PhotoItem {
        let item = PhotoItem(
            id: UUID(),
            createdAt: Date(),
            imagePath: imagePath,
            coordinate: coordinate,
            shotStyle: shotStyle,
            filterPresetName: filterPresetName
        )
        try repository.save(item)
        return item
    }
}
