//
//  PhotoPin.swift
//  LensNote
//

import Foundation
import MapKit
import UIKit

/// 사진 핀의 출처를 구분하는 열거형.
/// LensNote 저장 경로와 PHPhotoLibrary 경로를 분리하여 UI에서 다르게 표현할 수 있게 한다.
enum PhotoPinSource: Equatable {
    /// SavePhotoUseCase를 통해 LensNote 내부 저장소에 저장된 사진
    case lensNote
    /// PHPhotoLibrary에서 읽어온 기기 사진 라이브러리 사진
    case library
}

/// 한 장의 사진을 지도에 표시하기 위한 최소 정보(좌표/제목/썸네일 등)
struct PhotoPin: Identifiable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let title: String
    let createdAt: Date
    let assetLocalIdentifier: String?
    let thumbnail: UIImage?
    /// 이 핀이 어디서 왔는지 — LensNote 저장 경로 또는 PHPhotoLibrary
    let source: PhotoPinSource

    /// MKMapKit에서 사용하는 좌표 타입으로 변환한 값
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 클러스터링 결과를 표현하는 아이템(단일 핀 또는 여러 핀이 모인 클러스터)
struct ClusterItem: Identifiable {
    enum Kind { case single(PhotoPin); case cluster(center: CLLocationCoordinate2D, pins: [PhotoPin]) }
    let id: UUID
    let kind: Kind
    var coordinate: CLLocationCoordinate2D {
        switch kind {
        case .single(let pin): return pin.coordinate
        case .cluster(let center, _): return center
        }
    }
}

/// 클러스터 동등성 비교: 단일은 내부 핀 비교, 클러스터는 중심과 포함된 핀 배열 비교
extension ClusterItem.Kind: Equatable {
    static func == (lhs: ClusterItem.Kind, rhs: ClusterItem.Kind) -> Bool {
        switch (lhs, rhs) {
        case let (.single(a), .single(b)):
            return a == b
        case let (.cluster(centerA, pinsA), .cluster(centerB, pinsB)):
            return centerA.latitude == centerB.latitude &&
                   centerA.longitude == centerB.longitude &&
                   pinsA == pinsB
        default:
            return false
        }
    }
}

/// 아이템 동등성 비교는 고유 id 기준
extension ClusterItem: Equatable {
    static func == (lhs: ClusterItem, rhs: ClusterItem) -> Bool {
        lhs.id == rhs.id
    }
}
