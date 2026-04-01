//
//  LocationProvider.swift
//  LensNote
//
//  Created by 박태영 on 3/31/26.
//

import Foundation
import Combine
import CoreLocation

/// 카메라 촬영 시 현재 위치를 GeoCoordinate로 제공하는 서비스.
/// CLLocationManager를 래핑하여 MainActor 경계를 준수하고,
/// CameraViewModel에서 saveCapturedImage 호출 시 참조한다.
@MainActor
final class LocationProvider: NSObject, ObservableObject {

    /// 가장 최근에 수신된 위치 좌표. 아직 수신 전이거나 권한이 없으면 nil.
    @Published private(set) var latestCoordinate: GeoCoordinate?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// 위치 권한을 요청하고 업데이트를 시작한다.
    /// 이미 권한이 있으면 곧바로 업데이트를 시작한다.
    func start() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    /// 배터리 보존을 위해 위치 업데이트를 중지한다.
    func stop() {
        manager.stopUpdatingLocation()
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        let coord = GeoCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor in
            self.latestCoordinate = coord
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // 위치 획득 실패는 조용히 처리한다.
        // latestCoordinate는 nil 상태로 유지되어 저장 시 위치 없음 경고로 이어진다.
    }
}
