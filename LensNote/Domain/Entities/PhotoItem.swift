//
//  PhotoItem.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation
import CoreLocation

/// 지오태깅 좌표 정보.
struct GeoCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
}

/// 앱 내부 사진 메타데이터 엔티티.
/// 실제 파일 경로와 위치 정보를 함께 저장해 지도/갤러리에서 재사용한다.
struct PhotoItem: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let imagePath: String
    let coordinate: GeoCoordinate?
    /// 촬영 당시 적용된 ShotStyle. 레퍼런스 분석 없이 촬영하면 nil.
    /// Profile 통계(가장 많이 쓴 스타일) 집계에 사용한다.
    let shotStyle: ShotStyle?
    /// 촬영 당시 적용된 FilterPreset 이름. 프리셋 미적용 시 nil.
    let filterPresetName: String?

    init(
        id: UUID,
        createdAt: Date,
        imagePath: String,
        coordinate: GeoCoordinate?,
        shotStyle: ShotStyle? = nil,
        filterPresetName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.imagePath = imagePath
        self.coordinate = coordinate
        self.shotStyle = shotStyle
        self.filterPresetName = filterPresetName
    }
}
