//
//  MapRegionFilter.swift
//  LensNote
//
//  Req 6.7 — 좌표가 지도 영역(MKCoordinateRegion) 안에 있는지 판정하는 순수 함수.
//  지역 기반 목록 필터링에 사용하며, 테스트 가능하도록 분리했다.
//

import MapKit

enum MapRegionFilter {
    /// 좌표가 영역 박스(center ± span/2) 안에 포함되는지 판정한다.
    static func contains(_ coordinate: CLLocationCoordinate2D, in region: MKCoordinateRegion) -> Bool {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let latMin = region.center.latitude - halfLat
        let latMax = region.center.latitude + halfLat
        let lonMin = region.center.longitude - halfLon
        let lonMax = region.center.longitude + halfLon
        return coordinate.latitude >= latMin
            && coordinate.latitude <= latMax
            && coordinate.longitude >= lonMin
            && coordinate.longitude <= lonMax
    }
}
