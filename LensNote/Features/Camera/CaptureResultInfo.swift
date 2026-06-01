//
//  CaptureResultInfo.swift
//  LensNote
//
//  Req 2 — 캡처 결과 카드에 표시할 프레젠테이션 모델.
//

import UIKit

/// 저장 완료된 한 장의 촬영 결과를 결과 카드에 표시하기 위한 값.
/// 역지오코딩이 진행 중이면 placeName이 nil이고, 실패/타임아웃이면 안내 문구가 채워진다.
struct CaptureResultInfo: Equatable {
    /// 저장된 PhotoItem의 id. "지도에서 보기" 시 해당 PhotoPin 선택에 사용.
    let photoID: UUID
    /// 촬영 이미지(썸네일).
    let thumbnail: UIImage?
    /// 역지오코딩으로 해석된 위치명. nil이면 아직 확인 중.
    var placeName: String?
    /// 적용된 FilterPreset 이름. 없으면 nil.
    let filterPresetName: String?
    /// 레퍼런스 기반 촬영의 ShotStyle 라벨(한국어). 레퍼런스 미설정 시 nil.
    let shotStyleLabel: String?
    /// 촬영 좌표. nil이면 지도 이동 불가.
    let coordinate: GeoCoordinate?

    /// 좌표가 있어 지도로 이동 가능한지 여부.
    var canNavigateToMap: Bool { coordinate != nil }
}
